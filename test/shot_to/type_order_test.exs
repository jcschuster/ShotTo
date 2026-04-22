defmodule ShotTo.TypeOrderTest do
  use ExUnit.Case, async: true

  alias ShotDs.Data.Type
  alias ShotTo.{Parameters, TypeOrder}

  describe "type_gt?/3 on base sorts" do
    test "uses the sort precedence strictly" do
      params = Parameters.new(sort_precedence: %{a: 2, b: 1, c: 0})
      assert TypeOrder.type_gt?(Type.new(:a), Type.new(:b), params)
      assert TypeOrder.type_gt?(Type.new(:b), Type.new(:c), params)
      refute TypeOrder.type_gt?(Type.new(:a), Type.new(:a), params)
      refute TypeOrder.type_gt?(Type.new(:b), Type.new(:a), params)
    end

    test "returns false for equal sorts (irreflexive)" do
      params = Parameters.new(sort_precedence: %{i: 1})
      refute TypeOrder.type_gt?(Type.new(:i), Type.new(:i), params)
    end
  end

  describe "type_gt?/3 on arrow types via the right-argument relation" do
    test "(T → U) ≻_T U" do
      # i → o ≻ o via ▷_r.
      params = Parameters.new()
      assert TypeOrder.type_gt?(Type.new(:o, :i), Type.new(:o), params)
    end

    test "right-congruence: T → U ≻ T → V iff U ≻ V" do
      # In uncurried form: %{goal: g, args: [T | Us]} ≻ %{goal: g', args: [T | Vs]}
      # iff %{goal: g, args: Us} ≻ %{goal: g', args: Vs}.
      params = Parameters.new(sort_precedence: %{a: 1, b: 0})

      # i → a  ≻  i → b  because a ≻ b.
      lhs = Type.new(:a, :i)
      rhs = Type.new(:b, :i)
      assert TypeOrder.type_gt?(lhs, rhs, params)

      # The opposite direction does not hold.
      refute TypeOrder.type_gt?(rhs, lhs, params)
    end

    test "non-matching left component kills the congruence" do
      params = Parameters.new(sort_precedence: %{a: 1, b: 0})
      # j → a  vs  i → b: left components differ (j ≠ i), no rule fires
      # beyond the ▷_r check, which also fails here.
      lhs = Type.new(:a, :j)
      rhs = Type.new(:b, :i)
      refute TypeOrder.type_gt?(lhs, rhs, params)
      refute TypeOrder.type_gt?(rhs, lhs, params)
    end

    test "base does not exceed a proper arrow" do
      params = Parameters.new(sort_precedence: %{a: 10, o: 0})
      refute TypeOrder.type_gt?(Type.new(:a), Type.new(:o, :i), params)
    end
  end

  describe "type_geq?/3" do
    test "reflexivity" do
      params = Parameters.new()
      assert TypeOrder.type_geq?(Type.new(:i), Type.new(:i), params)
      assert TypeOrder.type_geq?(Type.new(:o, :i), Type.new(:o, :i), params)
    end

    test "strictly-greater case" do
      params = Parameters.new(sort_precedence: %{a: 1, b: 0})
      assert TypeOrder.type_geq?(Type.new(:a), Type.new(:b), params)
    end
  end

  describe "occurs_in?/2" do
    test "detects sort occurrence inside nested function types" do
      # o → (i → o) in uncurried form: %Type{goal: :o, args: [%Type{goal: :o, args: [:i]}]}
      nested = Type.new(Type.new(:o, :i), [])

      assert TypeOrder.occurs_in?(:o, nested)
      assert TypeOrder.occurs_in?(:i, nested)
      refute TypeOrder.occurs_in?(:j, nested)
    end

    test "detects goal-only occurrence" do
      assert TypeOrder.occurs_in?(:i, Type.new(:i))
      refute TypeOrder.occurs_in?(:o, Type.new(:i))
    end
  end
end
