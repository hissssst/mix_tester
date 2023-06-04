defmodule MixTester.AST do
  @moduledoc """
  Module with helpers for working with AST
  """

  @doc """
  Traverses AST looking for specific pattern
  """
  def find(ast, predicate, default \\ nil) do
    Macro.prewalk(ast, default, fn ast, default ->
      if predicate.(ast), do: throw(ast)
      {ast, default}
    end)

    default
  catch
    data -> data
  end
end
