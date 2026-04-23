defmodule ShotTo do
  @moduledoc """
  `ShotTo` provides a decidable instance of the βη-long-normal Computability
  Path Order (NCPO-LNF) of Niederhauser and Middeldorp (*NCPO goes
  Beta-Eta-Long Normal Form*, 2025) for terms of Church's simple type theory
  as represented by the `shot_ds` library.

  The order is parameterised by a sort precedence, a constant precedence
  with associated statuses and accessibility, and a choice of basic sorts;
  see `ShotTo.Parameters`. Given a fixed choice of parameters the relation
  `s > t` is a decidable boolean predicate that `ShotTo` implements directly
  rather than as an SMT constraint, making it suitable for use as an
  orientation order inside tableau and other proof-search procedures.

  ## Status

  As of the date of the paper, NCPO-LNF is *not known* to be transitive;
  the authors prove only the properties needed for termination of
  higher-order rewrite systems (well-foundedness, monotonicity,
  βη-long-normal stability). `ShotTo` is therefore best used pairwise — to
  decide whether one term should be oriented above another — rather than
  as the basis of a total comparator over a collection of terms. Using it
  as a key for sorting in particular may give surprising results until
  transitivity is established.

  ## Example

      iex> import ShotDs.Hol.Definitions
      iex> alias ShotDs.Stt.TermFactory, as: TF
      iex> alias ShotTo.Parameters
      ...>
      iex> # Constants f and c of base type i, with f > c in precedence.
      iex> params = Parameters.new(const_precedence: %{"f" => 1, "c" => 0})
      iex> f = TF.make_const_term("f", Type.new(:i, :i))
      iex> c = TF.make_const_term("c", type_i())
      iex> fc = ShotDs.Hol.Dsl.app(f, c)
      ...>
      iex> # f(c) > c by ⟨F▷⟩ (c is a subterm of f(c)).
      iex> ShotTo.gt?(fc, c, params)
      true
      iex> ShotTo.gt?(c, fc, params)
      false
  """

  alias ShotDs.Data.Term
  alias ShotTo.Parameters

  @doc """
  Returns `true` iff `s >^1_τ t` in NCPO-LNF under the given parameters.

  `s_id` and `t_id` are term IDs as produced by `ShotDs.Stt.TermFactory`.

  With no parameters supplied, the default (permissive) parameter set is
  used; see `ShotTo.Parameters` for details on the defaults.
  """
  @spec gt?(Term.term_id(), Term.term_id()) :: boolean()
  def gt?(s_id, t_id), do: gt?(s_id, t_id, Parameters.new())

  @spec gt?(Term.term_id(), Term.term_id(), Parameters.t()) :: boolean()
  def gt?(s_id, t_id, %Parameters{} = params),
    do: ShotTo.Ncpo.ncpo_gt?(s_id, t_id, params)

  @doc """
  Returns `true` iff `s ⪰^1_τ t` in NCPO-LNF, i.e. either the two terms are
  (structurally, thanks to ETS memoisation: referentially) equal or
  `s >^1_τ t`.
  """
  @spec geq?(Term.term_id(), Term.term_id()) :: boolean()
  def geq?(s_id, t_id), do: geq?(s_id, t_id, Parameters.new())

  @spec geq?(Term.term_id(), Term.term_id(), Parameters.t()) :: boolean()
  def geq?(s_id, t_id, %Parameters{} = params) do
    s_id == t_id or gt?(s_id, t_id, params)
  end

  @doc """
  Compares two term IDs in NCPO-LNF. Returns

    * `:greater`      if `s > t`,
    * `:less`         if `t > s`,
    * `:equal`        if the terms are structurally equal (same term ID), and
    * `:incomparable` otherwise.

  Because NCPO-LNF is not (yet known to be) transitive, the `:incomparable`
  case is a genuine possibility even for terms that intuitively "ought to
  be" comparable under some total ordering.

  Two NCPO-LNF calls are made in the worst case (once in each direction).
  Both are run inside a single scratchpad so intermediate fresh variables
  are collected together.
  """
  @spec compare(Term.term_id(), Term.term_id()) :: :greater | :less | :equal | :incomparable
  def compare(s_id, t_id), do: compare(s_id, t_id, Parameters.new())

  @spec compare(Term.term_id(), Term.term_id(), Parameters.t()) ::
          :greater | :less | :equal | :incomparable
  def compare(s_id, t_id, %Parameters{} = params) do
    cond do
      s_id == t_id -> :equal
      gt?(s_id, t_id, params) -> :greater
      gt?(t_id, s_id, params) -> :less
      true -> :incomparable
    end
  end
end
