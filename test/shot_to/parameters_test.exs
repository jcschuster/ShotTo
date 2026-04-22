defmodule ShotTo.ParametersTest do
  use ExUnit.Case, async: true

  alias ShotDs.Data.Type
  alias ShotTo.Parameters

  describe "defaults" do
    test "all constants are equivalent at rank 0" do
      p = Parameters.new()
      assert Parameters.prec(p, "f") == 0
      assert Parameters.prec(p, "g") == 0
      assert Parameters.equiv?(p, "f", "g")
      refute Parameters.gt?(p, "f", "g")
    end

    test "status defaults to :lex" do
      assert Parameters.status(Parameters.new(), "anything") == :lex
    end

    test "all sorts are basic by default" do
      assert Parameters.basic?(Parameters.new(), :i)
      assert Parameters.basic?(Parameters.new(), :some_unseen_sort)
    end

    test "all argument positions are accessible by default" do
      assert Parameters.accessible?(Parameters.new(), "f", 1)
      assert Parameters.accessible?(Parameters.new(), "f", 42)
    end
  end

  describe "from_precedence_list/2" do
    test "places constants in the given ordering and groups equivalences" do
      p = Parameters.from_precedence_list([["f"], ["g", "h"], ["c"]])
      assert Parameters.gt?(p, "f", "g")
      assert Parameters.gt?(p, "g", "c")
      assert Parameters.equiv?(p, "g", "h")
      refute Parameters.gt?(p, "h", "g")
      refute Parameters.gt?(p, "c", "f")
    end

    test "passes through additional options" do
      p = Parameters.from_precedence_list([["f"], ["g"]], status: %{"f" => :mul, "g" => :lex})
      assert Parameters.status(p, "f") == :mul
      assert Parameters.status(p, "g") == :lex
    end
  end

  describe "function-form lookups" do
    test "const_precedence accepts a function" do
      p = Parameters.new(const_precedence: fn name -> String.length(name) end)
      # "foo" (3) < "barbaz" (6).
      assert Parameters.gt?(p, "barbaz", "foo")
    end

    test "basic_sorts accepts a predicate" do
      p = Parameters.new(basic_sorts: fn s -> s == :i end)
      assert Parameters.basic?(p, :i)
      refute Parameters.basic?(p, :o)
    end

    test "accessible accepts a binary predicate" do
      p = Parameters.new(accessible: fn _name, i -> i == 1 end)
      assert Parameters.accessible?(p, "f", 1)
      refute Parameters.accessible?(p, "f", 2)
    end
  end

  describe "validate/2" do
    test "flags accessible arguments whose type contains a strictly greater sort" do
      # f: i → a, with a ≻ i in sort precedence. An accessible first arg of
      # type i is fine (no violation). Change things so that a appears in
      # the argument type but the return is i: violation.
      p =
        Parameters.new(
          sort_precedence: %{a: 1, i: 0},
          # all positions accessible by default
          accessible: :all
        )

      # g: a → i  — return type i is smaller than the sort a mentioned in
      # the argument type; this violates the accessibility condition.
      types = %{"g" => Type.new(:i, :a)}

      assert {:error, violations} = Parameters.validate(p, types)
      assert Enum.any?(violations, &String.contains?(&1, "g"))
    end

    test "passes when accessibility is vacuous" do
      # No constants at all — nothing to check.
      assert Parameters.validate(Parameters.new(), %{}) == :ok
    end

    test "flags basicness failures through accessible arguments" do
      p =
        Parameters.new(
          sort_precedence: %{a: 1, b: 0},
          # Only `a` is declared basic; b is not.
          basic_sorts: MapSet.new([:a])
        )

      # f: b → a — b appears in the accessible argument type but is not basic.
      types = %{"f" => Type.new(:a, :b)}
      assert {:error, violations} = Parameters.validate(p, types)
      assert Enum.any?(violations, &String.contains?(&1, ":b"))
    end
  end
end
