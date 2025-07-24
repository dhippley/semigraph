defmodule Semigraph.Query.ASTTest do
  use ExUnit.Case, async: true

  alias Semigraph.Query.AST

  describe "new/0" do
    test "creates empty AST" do
      ast = AST.new()

      assert ast.match_patterns == []
      assert ast.where_conditions == []
      assert ast.return_items == []
      assert ast.limit == nil
      assert ast.skip == nil
      assert ast.order_by == []
    end
  end

  describe "add_match_pattern/2" do
    test "adds match pattern to AST" do
      pattern = %{nodes: [], edges: []}

      ast = AST.new()
      |> AST.add_match_pattern(pattern)

      assert ast.match_patterns == [pattern]
    end

    test "appends multiple match patterns" do
      pattern1 = %{nodes: [%{variable: "a"}], edges: []}
      pattern2 = %{nodes: [%{variable: "b"}], edges: []}

      ast = AST.new()
      |> AST.add_match_pattern(pattern1)
      |> AST.add_match_pattern(pattern2)

      assert ast.match_patterns == [pattern1, pattern2]
    end
  end

  describe "add_where_condition/2" do
    test "adds where condition to AST" do
      condition = %{type: :comparison, left: %{variable: "n"}, op: :eq, right: "value"}

      ast = AST.new()
      |> AST.add_where_condition(condition)

      assert ast.where_conditions == [condition]
    end
  end

  describe "add_return_item/2" do
    test "adds return item to AST" do
      item = %{type: :variable, variable: "n"}

      ast = AST.new()
      |> AST.add_return_item(item)

      assert ast.return_items == [item]
    end
  end

  describe "set_return_items/2" do
    test "sets return items, replacing existing ones" do
      item1 = %{type: :variable, variable: "n"}
      item2 = %{type: :variable, variable: "m"}

      ast = AST.new()
      |> AST.add_return_item(item1)
      |> AST.set_return_items([item2])

      assert ast.return_items == [item2]
    end
  end

  describe "set_limit/2" do
    test "sets limit on AST" do
      ast = AST.new()
      |> AST.set_limit(10)

      assert ast.limit == 10
    end
  end

  describe "set_skip/2" do
    test "sets skip on AST" do
      ast = AST.new()
      |> AST.set_skip(5)

      assert ast.skip == 5
    end
  end

  describe "add_order_by/3" do
    test "adds order by clause" do
      ast = AST.new()
      |> AST.add_order_by("n", :asc)
      |> AST.add_order_by("m", :desc)

      assert ast.order_by == [{"n", :asc}, {"m", :desc}]
    end
  end
end
