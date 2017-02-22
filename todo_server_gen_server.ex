defmodule TodoList do
  use GenServer

  defstruct auto_id: 1, entries: Map.new

  def start(), do: GenServer.start(TodoList, nil)

  def init(_), do: {:ok, %TodoList{}}

  def add_entry(pid, entry), do: GenServer.cast(pid, {:add_entry, entry})

  def entries(pid, date), do: GenServer.call(pid, {:entries, date})

  def update_entry(pid, entry_id, updater_fn), do: GenServer.cast(pid, {:update_entry, entry_id, updater_fn}) 
  def update_entry(pid, %{} = new_entry), do: update_entry(pid, new_entry.id, fn(_) -> new_entry end)

  def delete_entry(pid, entry_id), do: GenServer.cast(pid, {:delete_entry, entry_id})

  def handle_cast({:add_entry, entry}, %TodoList{entries: entries, auto_id: auto_id} = todo_list) do
    entry = Map.put(entry, :id, auto_id)
    new_entries = Map.put(entries, auto_id, entry)

    {:noreply, %TodoList{todo_list | entries: new_entries, auto_id: auto_id + 1}}
  end

  def handle_cast({:update_entry, entry_id, updater_fn}, %TodoList{entries: entries} = todo_list) do
    result = 
      case entries[entry_id] do
        nil -> todo_list
        old_entry -> 
          old_entry_id = old_entry.id
          new_entry = %{id: ^old_entry_id} = updater_fn.(old_entry)
          new_entries = Map.put(todo_list.entries, new_entry.id, new_entry)
          %TodoList{todo_list | entries: new_entries}
      end
    {:noreply, result}
  end

  def handle_cast({:delete_entry, entry_id}, %TodoList{entries: entries} = todo_list) do
    result = 
      case entries[entry_id] do
        nil -> todo_list
        _ ->
          new_entries = Map.delete(entries, entry_id)
          %TodoList{todo_list | entries: new_entries}
      end
    {:noreply, result}
  end

  def handle_call({:entries, date}, _, %TodoList{entries: entries} = todo_list) do
    entries =
      entries
      |> Stream.filter(fn({_, entry}) -> entry.date == date end)
      |> Enum.map(fn{_, entry} -> entry end)
    {:reply, entries, todo_list}
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
