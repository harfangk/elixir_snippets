defmodule TodoList do
  defstruct auto_id: 1, entries: Map.new

  def new(entries \\ []), do: Enum.reduce(entries, %TodoList{}, &add_entry(&2, &1))

  def add_entry(%TodoList{entries: entries, auto_id: auto_id} = todo_list, entry) do
    entry = Map.put(entry, :id, auto_id)
    new_entries = Map.put(entries, auto_id, entry)

    %TodoList{todo_list | entries: new_entries, auto_id: auto_id + 1}
  end

  def update_entry(todo_list, %{} = new_entry) do
    update_entry(todo_list, new_entry.id, fn(_) -> new_entry end)
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

  def delete_entry(%TodoList{entries: entries} = todo_list, entry_id) do
    case entries[entry_id] do
      nil -> todo_list
      _ ->
        new_entries = Map.delete(entries, entry_id)
        %TodoList{todo_list | entries: new_entries}
    end
  end

  def entries(%TodoList{entries: entries}, date) do
    entries
    |> Stream.filter(fn({_, entry}) -> entry.date == date end)
    |> Enum.map(fn{_, entry} -> entry end)
  end
end

defmodule TodoServer do
  use GenServer

  def start(), do: GenServer.start(TodoList, nil)

  def add_entry(pid, entry), do: GenServer.cast(pid, {:add_entry, entry})

  def entries(pid, date), do: GenServer.call(pid, {:entries, date})

  def update_entry(pid, %{} = new_entry), do: update_entry(pid, new_entry.id, fn(_) -> new_entry end)
  def update_entry(pid, entry_id, updater_fn), do: GenServer.cast(pid, {:update_entry, entry_id, updater_fn}) 

  def delete_entry(pid, entry_id), do: GenServer.cast(pid, {:delete_entry, entry_id})

  def init(_), do: {:ok, TodoList.new()}

  def handle_cast({:add_entry, new_entry}, todo_list) do
    new_state = TodoList.add_entry(todo_list, new_entry)
    {:noreply, new_state}
  end

  def handle_cast({:update_entry, entry_id, updater_fn}, todo_list) do
    new_state = TodoList.update_entry(todo_list, entry_id, updater_fn)
    {:noreply, new_state}
  end

  def handle_cast({:delete_entry, entry_id}, todo_list) do
    new_state = TodoList.delete_entry(todo_list, entry_id)
    {:noreply, new_state}
  end

  def handle_call({:entries, date}, todo_list) do
    {:reply, TodoList.entries(todo_list, date), todo_list}
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
