defmodule ShotToTest do
  use ExUnit.Case, async: false

  # These tests exercise `ShotTo` against real `ShotDs` terms. They rely on
  # the global ETS term pool, which is why the suite runs with
  # `async: false`: the memoisation is process-shared and can interact
  # between concurrent tests.

  import ShotDs.Hol.Dsl
  import ShotDs.Hol.Definitions
  alias ShotDs.Stt.TermFactory, as: TF
  alias ShotTo.Parameters

  describe "basic properties" do
    test "irreflexivity: no term is strictly greater than itself" do
      c = TF.make_const_term("c", type_i())
      refute ShotTo.gt?(c, c)
    end

    test "a term equals itself under compare/3" do
      c = TF.make_const_term("c", type_i())
      assert ShotTo.compare(c, c) == :equal
    end

    test "a variable cannot stand on the left of >" do
      # Variable-headed terms are versatile — no NCPO rule fires.
      x = TF.make_free_var_term("X", type_i())
      c = TF.make_const_term("c", type_i())
      refute ShotTo.gt?(x, c)
    end
  end

  describe "⟨F▷⟩ — direct subterm" do
    test "f(c) > c for a unary f" do
      params = Parameters.new()
      f = TF.make_const_term("f", type_ii())
      c = TF.make_const_term("c", type_i())
      fc = app(f, c)
      assert ShotTo.gt?(fc, c, params)
      refute ShotTo.gt?(c, fc, params)
    end

    test "f(g(c)) > g(c) and f(g(c)) > c" do
      params = Parameters.new()
      f = TF.make_const_term("f", type_ii())
      g = TF.make_const_term("g", type_ii())
      c = TF.make_const_term("c", type_i())
      gc = app(g, c)
      fgc = app(f, gc)
      assert ShotTo.gt?(fgc, gc, params)
      assert ShotTo.gt?(fgc, c, params)
    end
  end

  describe "⟨F≻⟩ — precedence on constants" do
    test "f(c) > g(c) when f ≻ g (and every arg of RHS is dominated)" do
      params =
        Parameters.new(const_precedence: %{"f" => 2, "g" => 1, "c" => 0})

      f = TF.make_const_term("f", type_ii())
      g = TF.make_const_term("g", type_ii())
      c = TF.make_const_term("c", type_i())
      fc = app(f, c)
      gc = app(g, c)
      assert ShotTo.gt?(fc, gc, params)
      refute ShotTo.gt?(gc, fc, params)
    end

    test "flipping the precedence flips the result" do
      params_fg =
        Parameters.new(const_precedence: %{"f" => 2, "g" => 1, "c" => 0})

      params_gf =
        Parameters.new(const_precedence: %{"f" => 1, "g" => 2, "c" => 0})

      f = TF.make_const_term("f", type_ii())
      g = TF.make_const_term("g", type_ii())
      c = TF.make_const_term("c", type_i())
      fc = app(f, c)
      gc = app(g, c)

      assert ShotTo.gt?(fc, gc, params_fg)
      assert ShotTo.gt?(gc, fc, params_gf)
    end
  end

  describe "⟨F=lex⟩ and ⟨F=mul⟩ — same-head argument comparison" do
    setup do
      # A binary function with both arguments of the same type so both
      # :lex and :mul extensions can be exercised uniformly.
      h = TF.make_const_term("h", type_iii())
      a = TF.make_const_term("a", type_i())
      b = TF.make_const_term("b", type_i())
      %{h: h, a: a, b: b}
    end

    test "lex: h(a, b) > h(a, a) when a is the same and h(a,b) > a dominates the tail",
         %{h: h, a: a, b: b} do
      # Precedence a ≻ b so that the single differing position b vs a is
      # resolved via subterm dominance indirectly.
      params =
        Parameters.new(
          const_precedence: %{"h" => 2, "a" => 1, "b" => 0},
          status: %{"h" => :lex}
        )

      lhs = app(h, [a, a])
      rhs = app(h, [a, b])
      # lhs and rhs share the head and the first argument; lex moves on
      # to position 2 where a ≻ b via the h(a,a) > b check carried by ⟨F≻⟩.
      assert ShotTo.gt?(lhs, rhs, params)
    end

    test "lex is not symmetric: swapping the arguments flips the result",
         %{h: h, a: a, b: b} do
      params =
        Parameters.new(
          const_precedence: %{"h" => 2, "a" => 1, "b" => 0},
          status: %{"h" => :lex}
        )

      lhs = app(h, [a, a])
      rhs = app(h, [a, b])

      refute ShotTo.gt?(rhs, lhs, params)
    end

    test "mul with identical multisets is not strictly greater (strictness fix)", %{
      h: h,
      a: a
    } do
      params =
        Parameters.new(
          const_precedence: %{"h" => 2, "a" => 1},
          status: %{"h" => :mul}
        )

      lhs = app(h, [a, a])
      rhs = app(h, [a, a])
      refute ShotTo.gt?(lhs, rhs, params)
    end

    test "mul: h(a, a) > h(a, b) when a ≻ b and the extra a dominates b",
         %{h: h, a: a, b: b} do
      # Multisets: ss = [a, a], ts = [a, b]. ss \\ ts = [a], ts \\ ss = [b].
      # We need every element of [b] to be dominated by some element of [a].
      params =
        Parameters.new(
          const_precedence: %{"h" => 2, "a" => 1, "b" => 0},
          status: %{"h" => :mul}
        )

      lhs = app(h, [a, a])
      rhs = app(h, [a, b])
      assert ShotTo.gt?(lhs, rhs, params)
    end
  end

  describe "compare/3 trichotomy" do
    test "returns :greater, :less, :equal, or :incomparable" do
      params = Parameters.new(const_precedence: %{"f" => 1, "c" => 0})
      f = TF.make_const_term("f", type_ii())
      c = TF.make_const_term("c", type_i())
      fc = app(f, c)

      assert ShotTo.compare(fc, c, params) == :greater
      assert ShotTo.compare(c, fc, params) == :less
      assert ShotTo.compare(c, c, params) == :equal

      # Two unrelated constants of the same type and equivalent precedence.
      d = TF.make_const_term("d", type_i())
      assert ShotTo.compare(c, d, params) == :incomparable
    end
  end

  describe "⟨Fλ⟩, ⟨λ=⟩, ⟨λ▷⟩ — rules involving lambdas" do
    test "⟨λ=⟩ matched-binder lambdas delegate to ⟨F≻⟩ subgoal" do
      # In βη-long NF, the constant f : i → i is represented as λx. f(x),
      # so this is really a λ-vs-λ comparison. ⟨λ=⟩ opens both binders
      # with a fresh z:i and drops to the untyped subgoal f(z) > c, which
      # ⟨F≻⟩ discharges since f ≻ c and c has no arguments to dominate.
      params = Parameters.new(const_precedence: %{"f" => 2, "c" => 1})
      f = TF.make_const_term("f", type_ii())
      c = TF.make_const_term("c", type_i())
      lam_xc = lambda(type_i(), fn _x -> c end)

      assert ShotTo.gt?(f, lam_xc, params)
      refute ShotTo.gt?(lam_xc, f, params)
    end

    test "⟨λ▷⟩: λx.f(c) > c after opening the body" do
      params = Parameters.new()
      f = TF.make_const_term("f", type_ii())
      c = TF.make_const_term("c", type_i())

      lam = lambda(type_i(), fn _x -> app(f, c) end)
      # Opening λx yields f(c); then f(c) ≥_τ c by ⟨F▷⟩.
      assert ShotTo.gt?(lam, c, params)
    end

    test "⟨Fλ⟩ fires as a subgoal when the RHS argument is a non-trivial λ" do
      # Setup: h : o,  g : (i→o) → o,  q : o,  with precedence h ≻ g ≻ q.
      # Goal:  h > g(λx:i. q).
      # Path:  ⟨F≻⟩ (h ≻ g) recurses into  h > λx.q  without τ,
      #        ⟨Fλ⟩ opens the λ with fresh z:i (adding z to X) and
      #        recurses into  h > q, closed by ⟨F≻⟩ since q has no args.
      #
      # This is the *only* way ⟨Fλ⟩ can fire: the outer τ-check forbids
      # comparing a base-typed constant-headed LHS directly against a λ of
      # arrow type, so ⟨Fλ⟩ must be reached via a τ-free recursive call
      # like the one inside ⟨F≻⟩.
      params =
        Parameters.new(const_precedence: %{"h" => 3, "g" => 2, "q" => 1})

      h = TF.make_const_term("h", type_o())
      g = TF.make_const_term("g", type_io_o())
      q = TF.make_const_term("q", type_o())

      lam_q = lambda(type_i(), fn _x -> q end)
      g_lam = app(g, lam_q)

      assert ShotTo.gt?(h, g_lam, params)
      refute ShotTo.gt?(g_lam, h, params)
    end
  end
end
