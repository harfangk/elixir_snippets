defmodule LLRBTree do
  @moduledoc """
  Implementation of left-leaning red black binary search tree.
  Detailed discussion can be found in Robrt Sedgewick's slides:
  http://www.cs.princeton.edu/~rs/talks/LLRB/RedBlack.pdf

  Supports only integer as key.
  """

  @typedoc """
  Node for the left-leaning red black binary search tree.
  {left_child, key, value, is_node_red, right_child}
  """
  @type llrb_node :: {llrb_node, integer, any, boolean, llrb_node} | {:error, String.t, llrb_node}

  @spec put(llrb_node, integer, any) :: llrb_node
  def put(node, nil, _), do: {:error, "Key cannot be nil", node}
  def put(node, k, _) when (not is_integer(k)), do: {:error, "Key is not of integer type", node}
  def put(nil, k, v), do: {nil, k, v, true, nil}
  def put({lc, node_k, node_v, is_red, rc}, k, v) do
    cond do
      k == node_k -> {lc, k, v, is_red, rc}
      k  < node_k -> {put(lc, k, v), node_k, node_v, is_red, rc}
      k  > node_k -> {lc, node_k, node_v, is_red, put(rc, k, v)} 
    end
    |> balance_tree()
  end

  @spec get(llrb_node, integer) :: any
  def get(nil, _), do: nil
  def get(node, nil), do: {:error, "Key cannot be nil", node}
  def get(node, k) when (not is_integer(k)), do: {:error, "Key is not of integer type", node}
  def get({_, node_k, node_v, _, _}, k) when k == node_k, do: node_v
  def get({lc, node_k, _, _, _}, k) when k < node_k, do: get(lc, k)
  def get({_, node_k, _, _, rc}, k) when k > node_k, do: get(rc, k)
  
  @spec delete(llrb_node, integer) :: llrb_node
  def delete(nil, _), do: {:error, "Tree cannot be nil", nil}
  def delete(node, nil), do: {:error, "Key cannot be nil", node}
  def delete(node, k) when (not is_integer(k)), do: {:error, "Key is not of integer type", node}
  def delete({_, node_k, _, _, _} = node, k) do
    cond do
      k < node_k -> if not is_lc_red(node) and not is_lc_lc_red(node) do
                      node |> move_red_left() |> replace_lc_with_delete_lc(k) |> balance_tree()
                    else
                      node |> replace_lc_with_delete_lc(k) |> balance_tree()
                    end
      k > node_k -> node = if is_lc_red(node) do rotate_right(node) else node end 
                    node = if not is_rc_red(node) and not is_rc_lc_red(node) do move_red_right(node) else node end
                    node |> replace_rc_with_delete_rc(k) |> balance_tree()
      k == node_k -> node = if is_lc_red(node) do rotate_right(node) else node end
                     node |> do_delete() |> balance_tree()
    end
  end

  defp replace_rc_with_delete_rc({lc, k, v, is_red, rc}, key), do: {lc, k, v, is_red, delete(rc, key)}
  defp replace_lc_with_delete_lc({lc, k, v, is_red, rc}, key), do: {delete(lc, key), k, v, is_red, rc} 
  
  defp do_delete({lc, _, _, is_red, rc}) do
    min_key = min_key_of(rc)
    case rc do
      nil -> nil
      _ -> {lc, min_key, get(rc, min_key), is_red, delete_min(rc)}
    end
  end

  @spec delete_max(llrb_node) :: llrb_node
  def delete_max(nil), do: nil
  def delete_max(node) do
    node = 
      if is_lc_red(node) do
        rotate_right(node)
      else
        node
      end

    case node do
      {_, _, _, _, nil} -> nil
      _ -> if not is_rc_red(node) and not is_rc_lc_red(node) do
              node |> move_red_right() |> replace_rc_with_delete_max_rc() |> balance_tree()
           else
              node |> replace_rc_with_delete_max_rc() |> balance_tree()
           end 
    end
  end

  defp replace_rc_with_delete_max_rc({lc, k, v, is_red, rc}), do: {lc, k, v, is_red, delete_max(rc)}

  @spec delete_min(llrb_node) :: llrb_node
  def delete_min(nil), do: nil
  def delete_min(node) do
    case node do
      {nil, _, _, _, _} -> nil
      _ -> if not is_lc_red(node) and not is_lc_lc_red(node) do
             node |> move_red_left() |> replace_lc_with_delete_min_lc() |> balance_tree()
           else
             node |> replace_lc_with_delete_min_lc() |> balance_tree()
           end
    end
  end

  defp replace_lc_with_delete_min_lc({lc, k, v, is_red, rc}), do: {delete_min(lc), k, v, is_red, rc}

  defp min_key_of(nil), do: nil
  defp min_key_of({lc, node_k, _, _, _}) do
    case lc do
      nil -> node_k
      _ -> min_key_of(lc)
    end
  end

  defp rotate_left({lc, k, v, is_red, rc}) do
    {rc_lc, rc_k, rc_v, _, rc_rc} = rc
    {{lc, k, v, true, rc_lc}, rc_k, rc_v, is_red, rc_rc}
  end

  defp rotate_right({lc, k, v, is_red, rc}) do
    {lc_lc, lc_k, lc_v, _, lc_rc} = lc
    {lc_lc, lc_k, lc_v, is_red, {lc_rc, k, v, true, rc}}
  end

  defp flip_color({lc, k, v, is_red, rc}) do
    {lc_lc, lc_k, lc_v, lc_is_red, lc_rc} = lc
    {rc_lc, rc_k, rc_v, rc_is_red, rc_rc} = rc
    {{lc_lc, lc_k, lc_v, not lc_is_red, lc_rc}, k, v, not is_red, {rc_lc, rc_k, rc_v, not rc_is_red, rc_rc}}
  end

  defp get_lc(nil), do: nil
  defp get_lc({lc, _, _, _, _}), do: lc

  defp get_rc(nil), do: nil
  defp get_rc({_, _, _, _, rc}), do: rc

  defp is_red(nil), do: false
  defp is_red({_, _, _, false, _}), do: false
  defp is_red({_, _, _, true, _}), do: true

  defp is_lc_red(node) do
    node
    |> get_lc()
    |> is_red()
  end

  defp is_rc_red(node) do
    node
    |> get_rc()
    |> is_red()
  end

  defp is_lc_lc_red(node) do
    node
    |> get_lc()
    |> get_lc()
    |> is_red()
  end

  defp is_rc_lc_red(node) do
    node
    |> get_rc()
    |> get_lc()
    |> is_red()
  end

  defp balance_tree(nil), do: nil
  defp balance_tree(node) do
    node = if is_rc_red(node) do rotate_left(node) else node end
    node = if is_lc_red(node) and is_lc_lc_red(node) do rotate_right(node) else node end
    if is_lc_red(node) and is_rc_red(node) do flip_color(node) else node end
  end

  defp move_red_right(nil), do: nil
  defp move_red_right(node) do
    node = flip_color(node)
    if is_lc_lc_red(node) do
      node
      |> rotate_right()
      |> flip_color()
    else
      node
    end
  end

  defp move_red_left(nil), do: nil
  defp move_red_left(node) do
    node = flip_color(node)
    if is_rc_lc_red(node) do
      {lc, k, v, is_red, rc} = node
      {lc, k, v, is_red, rotate_right(rc)}
      |> rotate_left()
      |> flip_color()
    else
      node
    end
  end
end
