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

defmodule KeyValueStore do
  def start(), do: ServerProcess.start()
  def init(), do: Map.new()

  def put(pid, key, value), do: ServerProcess.cast(pid, {:put, key, value})
  def get(pid, key), do: ServerProcess.call(pid, {:get, key})
  
  def handle_call({:put, key, value}, state) do
    {:ok, Map.put(state, key, value)}
  end

  def handle_call({:get, key}, state) do
    {Map.get(state, key), state}
  end
  
  def handle_cast({:get, key}, state) do
    {Map.get(state, key), state}
  end
end
