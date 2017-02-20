defmodule Calculator do
  def start() do
    spawn(fn -> loop(0) end)
  end

  def value(calculator_pid) do
    send(calculator_pid, {:value, self()})
    receive do
      {:ok, value} -> value
    end
  end

  def add(calculator_pid, n), do: send(calculator_pid, {:add, n})
  def sub(calculator_pid, n), do: send(calculator_pid, {:sub, n})
  def mul(calculator_pid, n), do: send(calculator_pid, {:mul, n})
  def div(calculator_pid, n), do: send(calculator_pid, {:div, n})

  defp loop(current_value) do
    new_value = receive do
      message -> process_message(current_value, message)
    end
    loop(new_value)
  end
  
  defp process_message(current_value, {:value, caller}) do
    send(caller, {:ok, current_value})
    current_value
  end
  defp process_message(current_value, {:add, n}), do: current_value + n
  defp process_message(current_value, {:sub, n}), do: current_value - n
  defp process_message(current_value, {:mul, n}), do: current_value * n
  defp process_message(current_value, {:div, n}), do: current_value / n
  defp process_message(current_value, invalid_request) do
    IO.puts "invalid request #{inspect invalid_request}"
    current_value
  end
end
