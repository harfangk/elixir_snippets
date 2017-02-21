defmodule TodoServer do
  def init(), do: TodoList.new()
  def start(), do: ServerProcess.start(TodoServer)

  def add_entry(pid, entry), do: ServerProcess.cast(pid, {:add_entry, entry})
  def entries(pid, date), do: ServerProcess.call(pid, {:entries, date})
  def update_entry(pid, new_entry), do: ServerProcess.cast(pid, {:update_entry, new_entry})

  def handle_cast({:add_entry, entry}, state) do
    TodoList.add_entry(state, entry)
  end

  def handle_call({:entries, date}, state) do
    {TodoList.entries(state, date), state}
  end

  def handle_cast({:update_entry, new_entry}, state) do
    TodoList.update_entry(state, new_entry)
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

defmodule ServerProcess do
  def start(callback_module) do
    spawn(fn -> 
      initial_state = callback_module.init()
      loop(callback_module, initial_state)
    end)
  end

  def call(server_pid, request) do
    send(server_pid, {:call, request, self()})
    receive do
      {:response, response} -> response
    end
  end

  def cast(server_pid, request) do
    send(server_pid, {:cast, request})
  end

  defp loop(callback_module, current_state) do
    receive do
      {:call, request, caller} -> 
        {response, new_state} = callback_module.handle_call(request, current_state)
        send(caller, {:response, response})
        loop(callback_module, new_state)
      {:cast, request} ->
        new_state = callback_module.handle_cast(request, current_state)
        loop(callback_module, new_state)
    end
  end
end
