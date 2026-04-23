defmodule ShotTo.TypeOrder do
  @moduledoc """
  Admissible type order `≻_T` and related predicates used by NCPO-LNF.

  The order implemented here is the concrete admissible order of Lemma 4
  in the NCPO-LNF paper (Niederhauser & Middeldorp, 2025), which is in
  turn Lemma 2.3 of the CPO paper [Blanqui/Jouannaud/Rubio, 2015]. It is
  the smallest order `≻_T` on `ShotDs.Data.Type.t` that contains:

    * the strict part of the user-supplied sort precedence `≻_S`, and
    * the *right-argument* relation `▷_r` (i.e. `T → U ▷_r U`),

  and is closed under right-congruence (`V ≻_T V'` implies
  `U → V ≻_T U → V'` for every `U`).

  Note: `ShotDs.Data.Type` represents function types in uncurried form, so
  `T_1 → T_2 → … → T_n → a` corresponds to
  `%Type{goal: a, args: [T_1, …, T_n]}`. The implementation is written
  directly on this representation rather than on a curried view.
  """

  alias ShotDs.Data.Type
  alias ShotTo.Parameters

  @doc """
  Returns `true` if `lhs ≻_T rhs` in the admissible type order derived
  from the sort precedence in `params`.

  Strict order: `type_gt?(t, t, _)` is always `false`.
  """
  @spec type_gt?(Type.t(), Type.t(), Parameters.t()) :: boolean()
  def type_gt?(%Type{} = lhs, %Type{} = rhs, %Parameters{} = params) do
    do_type_gt?(lhs, rhs, params)
  end

  @doc """
  Reflexive closure: `t ⪰_T u` iff `t = u` or `t ≻_T u`.
  """
  @spec type_geq?(Type.t(), Type.t(), Parameters.t()) :: boolean()
  def type_geq?(%Type{} = lhs, %Type{} = rhs, %Parameters{} = params) do
    lhs == rhs or do_type_gt?(lhs, rhs, params)
  end

  # Base vs base: decided by the sort precedence directly.
  defp do_type_gt?(%Type{args: []} = lhs, %Type{args: []} = rhs, params) do
    Parameters.sort_prec(params, lhs.goal) > Parameters.sort_prec(params, rhs.goal)
  end

  defp do_type_gt?(%Type{args: []}, %Type{args: [_ | _]}, _params), do: false

  defp do_type_gt?(%Type{args: [t | u_args]} = lhs, rhs, params) do
    u = %Type{goal: lhs.goal, args: u_args}

    rhs == u or
      case rhs do
        %Type{args: []} ->
          false

        %Type{args: [t_rhs | u_rhs_args]} = rhs_full ->
          t == t_rhs and
            do_type_gt?(u, %Type{goal: rhs_full.goal, args: u_rhs_args}, params)
      end
  end

  @doc """
  Returns `true` if the argument type is a base type (no function arrows).
  """
  @spec base?(Type.t()) :: boolean()
  def base?(%Type{args: []}), do: true
  def base?(%Type{}), do: false

  @doc """
  Returns `true` if the base sort `a` occurs anywhere within the given
  type. This is the boolean version of the `Pos_a(T) ≠ ∅` predicate used
  by the structurally-smaller rule: the paper's requirement
  `Pos_a(T_i) = ∅` translates to `not occurs_in?/2`.

      iex> alias ShotDs.Data.Type
      iex> alias ShotTo.TypeOrder
      iex> TypeOrder.occurs_in?(:i, Type.new(:o, [:i, :o]))
      true
      iex> TypeOrder.occurs_in?(:i, Type.new(:o))
      false
  """
  @spec occurs_in?(atom(), Type.t()) :: boolean()
  def occurs_in?(sort, %Type{goal: sort}), do: true

  def occurs_in?(sort, %Type{args: args}),
    do: Enum.any?(args, &occurs_in?(sort, &1))
end
