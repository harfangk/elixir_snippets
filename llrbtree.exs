defmodule LLRBTree do
  @moduledoc """
  Implementation of left-leaning red black binary search tree.
  Detailed discussion can be found in Robrt Sedgewick's slides:
  http://www.cs.princeton.edu/~rs/talks/LLRB/RedBlack.pdf

  Supports only integer as key.
  """

  @typedoc """
  Node for the left-leaning red black binary search tree.
  {value, left_child, right_child, is_link_to_parent_red}
  """
  @type llrb_node :: {integer, any, llrb_node, llrb_node, boolean} | {:error, String.t}

  @spec put(integer, any, llrb_node) :: llrb_node
  def put(nil, _, _), do: {:error, "Key cannot be nil"}
  def put(k, _, _) when not is_integer(k), do: {:error, "Key is not of integer type"}
  def put(k, v, nil), do: {k, v, nil, nil, true}
  def put(k, v, {node_k, _, left_child, right_child, is_red}) do
    cond do
      k == node_k -> {k, v, left_child, right_child, is_red}
      k  < node_k -> {k, v, put(k, v, left_child), right_child, is_red}
      k  > node_k -> {k, v, left_child, put(k, v, right_child), is_red} 
    end
    |> balance_tree()
  end

  @spec get(llrb_node, integer) :: any
  def get(_, nil), do: {:error, "Key cannot be nil"}
  def get(nil, _), do: nil
  def get(_, k) when not is_integer(k), do: {:error, "Key is not of integer type"}
  def get({node_k, node_v, _, _, _}, k) when k == node_k, do: node_v
  def get({node_k, _, left_child, _, _}, k) when k < node_k, do: get(k, left_child)
  def get({node_k, _, _, right_child, _}, k) when k > node_k, do: get(k, right_child)
  
  @spec delete(llrb_node, integer) :: llrb_node
  def delete(nil, _), do: {:error, "Tree cannot be nil"}
  def delete(_, nil), do: {:error, "Key cannot be nil"}
  def delete(_, k) when not is_integer(k), do: {:error, "Key is not of integer type"}
  def delete({node_k, _, _, _, _} = node, k) do
    cond do
      k < node_k -> if is_lc_and_lc_lc_black(node) do
                      node |> move_red_left() |> replace_lc_with_delete_lc(k) |> balance_tree()
                    else
                      node |> replace_lc_with_delete_lc(k) |> balance_tree()
                    end
      k > node_k -> node = if is_lc_red(node) do rotate_right(node) else node end 
                    node = if is_rc_and_rc_lc_black(node) do move_red_right(node) else node end
                    node |> replace_rc_with_delete_rc(k) |> balance_tree()
      k == node_k -> node = if is_lc_red(node) do rotate_right(node) else node end
                     node |> do_delete() |> balance_tree()
    end
  end

  defp replace_rc_with_delete_rc({k, v, lc, rc, is_red}, key), do: {k, v, lc, delete(rc, key), is_red}
  defp replace_lc_with_delete_lc({k, v, lc, rc, is_red}, key), do: {k, v, delete(lc, key), rc, is_red} 
  
  defp do_delete({_, _, lc, rc, is_red}) do
    min_key = min_key_of(rc)
    case rc do
      nil -> nil
      _ -> {min_key, get(rc, min_key), lc, delete_min(rc), is_red}
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
      {_, _, _, nil, _} -> nil
      _ -> if is_rc_and_rc_lc_black(node) do
              node |> move_red_right() |> replace_lc_with_delete_max_lc() |> balance_tree()
           else
              node |> replace_lc_with_delete_max_lc() |> balance_tree()
           end 
    end
  end

  defp replace_lc_with_delete_max_lc({k, v, lc, rc, is_red}), do: {k, v, delete_max(lc), rc, is_red}

  @spec delete_min(llrb_node) :: llrb_node
  def delete_min(nil), do: nil
  def delete_min({_, _, lc, _, _} = node) do
    case lc do
      nil -> nil
      _ -> if is_lc_and_lc_lc_black(node) do
             node |> move_red_left() |> replace_lc_with_delete_min_lc() |> balance_tree()
           else
             node |> replace_lc_with_delete_min_lc() |> balance_tree()
           end
    end
  end

  defp replace_lc_with_delete_min_lc({k, v, lc, rc, is_red}), do: {k, v, delete_min(lc), rc, is_red}

  defp min_key_of(node)
  defp min_key_of(nil), do: nil
  defp min_key_of({node_k, _, left_child, _, _}) do
    case left_child do
      nil -> node_k
      _ -> min_key_of(left_child)
    end
  end

  defp rotate_left({parent_k, parent_v, parent_lc, parent_rc, parent_is_red}) do
    {rc_k, rc_v, rc_left_child, rc_right_child, rc_is_red} = parent_rc
    {rc_k, rc_v, {parent_k, parent_v, parent_lc, rc_left_child, rc_is_red}, rc_right_child, parent_is_red}
  end

  defp rotate_right({parent_k, parent_v, parent_lc, parent_rc, parent_is_red}) do
    {lc_k, lc_v, lc_left_child, lc_right_child, lc_is_red} = parent_lc
    {lc_k, lc_v, lc_left_child, {parent_k, parent_v, lc_right_child, parent_rc, lc_is_red}, parent_is_red}
  end

  defp flip_color({parent_k, parent_v, parent_lc, parent_rc, parent_is_red}) do
    {lc_k, lc_v, lc_left_child, lc_right_child, lc_is_red} = parent_lc
    {rc_k, rc_v, rc_left_child, rc_right_child, rc_is_red} = parent_rc
    {parent_k, parent_v, {lc_k, lc_v, lc_left_child, lc_right_child, not lc_is_red}, {rc_k, rc_v, rc_left_child, rc_right_child, not rc_is_red}, not parent_is_red}
  end

  defp is_rc_red(nil), do: false
  defp is_rc_red({_, _, _, nil, _}), do: false
  defp is_rc_red({_, _, _, {_, _, _, _, true}, _}), do: true
  defp is_rc_red(_), do: false

  defp is_lc_red(nil), do: false
  defp is_lc_red({_, _, nil, _, _}), do: false
  defp is_lc_red({_, _, {_, _, _, _, true}, _, _}), do: true
  defp is_lc_red(_), do: false

  defp is_lc_and_lc_lc_red(nil), do: false
  defp is_lc_and_lc_lc_red({_, _, nil, _, _}), do: false
  defp is_lc_and_lc_lc_red({_, _, {_, _, nil, _, _}, _, _}), do: false
  defp is_lc_and_lc_lc_red({_, _, {_, _, {_, _, _, _, true}, _, true}, _, _}), do: true
  defp is_lc_and_lc_lc_red(_), do: false

  defp is_lc_and_lc_lc_black(nil), do: false
  defp is_lc_and_lc_lc_black({_, _, nil, _, _}), do: false
  defp is_lc_and_lc_lc_black({_, _, {_, _, nil, _, _}, _, _}), do: false
  defp is_lc_and_lc_lc_black({_, _, {_, _, {_, _, _, _, false}, _, false}, _, _}), do: true
  defp is_lc_and_lc_lc_black(_), do: false

  defp is_rc_lc_red(nil), do: false
  defp is_rc_lc_red({_, _, _, nil, _}), do: false
  defp is_rc_lc_red({_, _, _, {_, _, nil, _, _}, _}), do: false
  defp is_rc_lc_red({_, _, _, {_, _, {_, _, _, _, true}, _, _}, _}), do: true
  defp is_rc_lc_red(_), do: false

  defp is_rc_and_rc_lc_black(nil), do: false
  defp is_rc_and_rc_lc_black({_, _, _, nil, _}), do: false
  defp is_rc_and_rc_lc_black({_, _, _, {_, _, nil, _, _}, _}), do: false
  defp is_rc_and_rc_lc_black({_, _, _, {_, _, {_, _, _, _, false}, _, false}, _}), do: true
  defp is_rc_and_rc_lc_black(_), do: false

  defp is_lc_and_rc_red(nil), do: false
  defp is_lc_and_rc_red({_, _, nil, _, _}), do: false
  defp is_lc_and_rc_red({_, _, _, nil, _}), do: false
  defp is_lc_and_rc_red({_, _, {_, _, _, _, true}, {_, _, _, _, true}, _}), do: true
  defp is_lc_and_rc_red(_), do: false

  defp balance_tree(nil), do: nil
  defp balance_tree(node) do
    node = if is_rc_red(node) do rotate_left(node) else node end
    node = if is_lc_and_lc_lc_red(node) do rotate_right(node) else node end
    if is_lc_and_rc_red(node) do flip_color(node) else node end
  end

  defp move_red_right(nil), do: nil
  defp move_red_right(node) do
    node = flip_color(node)
    if is_lc_and_lc_lc_red(node) do
      node
      |> rotate_right()
      |> flip_color()
    end
  end

  defp move_red_left(nil), do: nil
  defp move_red_left(node) do
    node = flip_color(node)
    if is_rc_lc_red(node) do
      {k, v, lc, rc, is_red} = node
      {k, v, lc, rotate_right(rc), is_red}
      |> rotate_left()
      |> flip_color()
    end
  end
end
