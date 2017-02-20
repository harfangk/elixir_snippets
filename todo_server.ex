defmodule TodoServer do
  def start do
    server = spawn(fn -> loop(TodoList.new) end)
    Process.register(server, :todo_server)
    server
  end

  def add_entry(entry), do: add_entry(:todo_server, entry)
  def add_entry(server_pid, entry) do
    send(server_pid, {:add, entry})
  end

  def entries(date), do: entries(:todo_server, date)
  def entries(server_pid, date) do
    send(server_pid, {:entries, self(), date})
    receive do
      {:todo_entries, entries} -> entries
    after 5000 -> {:error, :timeout}
    end
  end

  defp loop(todo_list) do
    new_todo_list = 
      receive do
        message -> process_message(todo_list, message)
      end
    loop(new_todo_list)
  end

  defp process_message(todo_list, {:add, entry}) do
    TodoList.add_entry(todo_list, entry)
  end

  defp process_message(todo_list, {:entries, caller, date}) do
    send(caller, {:todo_entries, TodoList.entries(todo_list, date)})
    todo_list
  end
end

defmodule TodoList do
  defstruct auto_id: 1, entries: Map.new

  def new(entries \\ []) do
    Enum.reduce(entries, %TodoList{}, &add_entry(&2, &1))
  end

  def add_entry(%TodoList{entries: entries, auto_id: auto_id} = todo_list, entry) do
    entry = Map.put(entry, :id, auto_id)
    new_entries = Map.put(entries, auto_id, entry)

    %TodoList{todo_list | entries: new_entries, auto_id: auto_id + 1}
  end

  def entries(%TodoList{entries: entries}, date) do
    entries
    |> Stream.filter(fn({_, entry}) -> entry.date == date end)
    |> Enum.map(fn{_, entry} -> entry end)
  end

  def update_entry(%TodoList{entries: entries} = todo_list, entry_id, updater_fn) do
    case entries[entry_id] do
      nil -> todo_list
      old_entry -> 
        old_entry_id = old_entry.id
        new_entry = %{id: ^old_entry_id} = updater_fn.(old_entry)
        new_entries = Map.put(todo_list.entries, new_entry.id, new_entry)
        %TodoList{todo_list | entries: new_entries}
    end
  end

  def update_entry(todo_list, %{} = new_entry) do
    update_entry(todo_list, new_entry.id, fn(_) -> new_entry end)
  end

  def delete_entry(%TodoList{entries: entries} = todo_list, entry_id) do
    case entries[entry_id] do
      nil -> todo_list
      _ ->
        new_entries = Map.delete(entries, entry_id)
        %TodoList{todo_list | entries: new_entries}
    end
  end
end

defmodule TodoList.CsvImporter do
  def import(file) do
    file
    |> File.stream!()
    |> format_entry()
    |> TodoList.new()
  end

  defp format_entry(s) do
    s
    |> Stream.map(&String.replace(&1, "\n", ""))
    |> Stream.map(&String.split(&1, ","))
    |> Stream.map(fn([date_string, title_string]) -> [String.split(date_string, "/"), title_string] end)
    |> Stream.map(fn([[y, m, d], title_string]) -> [{String.to_integer(y), String.to_integer(m), String.to_integer(d)}, title_string] end)
    |> Enum.map(fn([date, title]) -> %{date: date, title: title} end)
  end
end
