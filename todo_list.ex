defmodule ToDoList do
  defstruct auto_id: 1, entries: Map.new

  def new(entries \\ []) do
    Enum.reduce(entries, %ToDoList{}, &add_entry(&2, &1))
  end

  def add_entry(%ToDoList{entries: entries, auto_id: auto_id} = todo_list, entry) do
    entry = Map.put(entry, :id, auto_id)
    new_entries = Map.put(entries, auto_id, entry)

    %ToDoList{todo_list | entries: new_entries, auto_id: auto_id + 1}
  end

  def entries(%ToDoList{entries: entries}, date) do
    entries
    |> Stream.filter(fn({_, entry}) -> entry.date == date end)
    |> Enum.map(fn{_, entry} -> entry end)
  end

  def update_entry(%ToDoList{entries: entries} = todo_list, entry_id, updater_fn) do
    case entries[entry_id] do
      nil -> todo_list
      old_entry -> 
        old_entry_id = old_entry.id
        new_entry = %{id: ^old_entry_id} = updater_fn.(old_entry)
        new_entries = Map.put(todo_list.entries, new_entry.id, new_entry)
        %ToDoList{todo_list | entries: new_entries}
    end
  end

  def update_entry(todo_list, %{} = new_entry) do
    update_entry(todo_list, new_entry.id, fn(_) -> new_entry end)
  end

  def delete_entry(%ToDoList{entries: entries} = todo_list, entry_id) do
    case entries[entry_id] do
      nil -> todo_list
      _ ->
        new_entries = Map.delete(entries, entry_id)
        %ToDoList{todo_list | entries: new_entries}
    end
  end
end

defmodule ToDoList.CsvImporter do
  def import(file) do
    file
    |> File.stream!()
    |> format_entry()
    |> ToDoList.new()
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
