defmodule Rps do
  def run(input) do
    if valid?(input) do
      input
      |> String.codepoints()
      |> Enum.zip(challenge())
      |> score()
      |> print_result()
    else
      IO.puts("bad input")
    end
  end

  def valid?(input) do
    input
    |> String.trim()
    |> String.codepoints()
    |> List.foldl(true, (fn(c, acc) -> ((c == "r") or (c == "p") or (c == "s")) and acc end))
  end

  def challenge() do
    [:rand.uniform(3), :rand.uniform(3), :rand.uniform(3)]
    |> Enum.map(fn f ->
      case f do
        1 -> "r" 
        2 -> "p"
        3 -> "s"
      end
    end)
  end

  def score(tuple_list) do
    List.foldl(tuple_list, 0, fn(tuple, acc) -> 
      case tuple do
        { "r", "s" } -> acc - 1
        { "r", "p" } -> acc + 1
        { "s", "r" } -> acc + -1
        { "s", "p" } -> acc + 1
        { "p", "r" } -> acc + 1
        { "p", "s" } -> acc + -1
        _ -> acc
      end
    end)
  end

  def print_result(score) do
    cond do
      score == 0 -> "Draw"
      score > 0 -> "Win"
      score < 0 -> "Lose"
    end
    |> IO.puts()
  end
end

input = IO.gets("Input: ")
Rps.run(input)
