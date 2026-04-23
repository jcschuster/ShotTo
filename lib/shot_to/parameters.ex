defmodule ShotTo.Parameters do
  @moduledoc """
  Parameters that define a concrete instance of NCPO-LNF.

  NCPO-LNF is parameterised by the following data (see Definition 8 and the
  surrounding text in Niederhauser & Middeldorp, *NCPO goes Beta-Eta-Long
  Normal Form*, 2025):

    * A well-founded strict order `≻_S` on base sorts (atoms). The
      admissible type order `≻_T` used inside NCPO is derived from this by
      Lemma 4.
    * A precedence `≿_F` on function symbols (constants) with a well-founded
      strict part `≻_F` and equivalence `≃_F`.
    * A status `stat(f) ∈ {:mul, :lex}` for each constant.
    * A predicate `basic(a)` selecting which base sorts are *basic*.
    * An accessibility predicate `Acc(f, i)` selecting which argument
      positions of each constant are *accessible*.

  For the Haskell reference, these are unknowns decided by an SMT solver so
  that termination of an entire rewrite system can be proven. In `ShotTo`
  we take them as fixed inputs and obtain a decidable boolean predicate on
  pairs of terms, which is what a tableau prover or equational-reasoning
  engine typically needs.

  ## Defaults

  The default parameter set is deliberately *permissive*: all sorts are
  basic and equivalent, all positions are accessible, all constants are
  equivalent in precedence with `:lex` status. Under these defaults NCPO
  reduces to the simple argument-subterm order together with lexicographic
  comparison inside shared heads, which is rarely what a user wants — the
  point is to make the API usable out of the box and to make it explicit
  that *every* meaningful orientation requires the user to supply at least
  a constant precedence.

  ## Validity of parameters

  Soundness of NCPO-LNF depends on `Acc` and `basic` satisfying the
  compatibility conditions of Definitions 5 & 6 with respect to the chosen
  type precedence. `ShotTo` does not currently check these conditions — it
  trusts the caller. `ShotTo.Parameters.validate/2` gives a best-effort
  check for a given set of constants; callers who need a soundness
  guarantee should either invoke it or default to `accessible: :all` and
  `basic_sorts: :all`, which are vacuously sound (the compatibility
  conditions become trivial when every position is accessible and every
  sort is basic).
  """

  alias ShotDs.Data.Type

  @typedoc """
  Identifier for a constant as used in `ShotDs.Data.Declaration.name`. In
  practice either a binary name or an Erlang reference (for generated
  constants).
  """
  @type const_id :: String.t() | reference()

  @typedoc """
  Identifier for a base sort, corresponding to `ShotDs.Data.Type.type_id`
  with the type-variable case excluded: an atom such as `:i`, `:o`, etc.
  """
  @type sort_id :: atom()

  @typedoc "Argument position, counted from 1."
  @type arg_index :: pos_integer()

  @typedoc "Symbol status."
  @type status :: :lex | :mul

  @typedoc """
  Constant precedence. Either a map from constant identifiers to integers
  (larger integer means greater in `≻_F`; equal integers mean `≃_F`), or a
  one-argument function with the same meaning.
  """
  @type const_precedence :: %{optional(const_id()) => integer()} | (const_id() -> integer())

  @typedoc """
  Sort precedence. Either a map from sort identifiers to integers or a
  one-argument function with the same meaning.
  """
  @type sort_precedence :: %{optional(sort_id()) => integer()} | (sort_id() -> integer())

  @typedoc "Status assignment. Either a map or a one-argument function."
  @type status_map :: %{optional(const_id()) => status()} | (const_id() -> status())

  @typedoc """
  Which sorts are basic. `:all` treats every sort as basic. A MapSet
  explicitly lists the basic sorts. A predicate function is also accepted.
  """
  @type basic_sorts :: :all | MapSet.t(sort_id()) | (sort_id() -> boolean())

  @typedoc """
  Which argument positions of which constants are accessible. `:all`
  treats every position as accessible. A MapSet contains `{const_id,
  index}` tuples. A predicate function is also accepted.
  """
  @type accessible ::
          :all
          | MapSet.t({const_id(), arg_index()})
          | (const_id(), arg_index() -> boolean())

  @type t :: %__MODULE__{
          sort_precedence: sort_precedence(),
          const_precedence: const_precedence(),
          status: status_map(),
          basic_sorts: basic_sorts(),
          accessible: accessible()
        }

  defstruct sort_precedence: %{},
            const_precedence: %{},
            status: %{},
            basic_sorts: :all,
            accessible: :all

  @doc """
  Builds a parameter struct. All keys are optional; unspecified fields fall
  back to the permissive defaults described in the module docs.

  ## Example

      iex> alias ShotTo.Parameters
      iex> params = Parameters.new(
      ...>   const_precedence: %{"f" => 2, "g" => 1, "c" => 0},
      ...>   status: %{"f" => :lex, "g" => :mul}
      ...> )
      iex> Parameters.prec(params, "f")
      2
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct!(__MODULE__, opts)
  end

  @doc """
  Looks up the precedence rank of a constant. Defaults to `0` for unknown
  constants, which makes unknown constants equivalent to each other and to
  any other rank-0 constant.
  """
  @spec prec(t(), const_id()) :: integer()
  def prec(%__MODULE__{const_precedence: fun}, name) when is_function(fun, 1),
    do: fun.(name)

  def prec(%__MODULE__{const_precedence: map}, name) when is_map(map),
    do: Map.get(map, name, 0)

  @doc """
  Looks up the precedence rank of a sort. Defaults to `0` for unknown sorts.
  """
  @spec sort_prec(t(), sort_id()) :: integer()
  def sort_prec(%__MODULE__{sort_precedence: fun}, sort) when is_function(fun, 1),
    do: fun.(sort)

  def sort_prec(%__MODULE__{sort_precedence: map}, sort) when is_map(map),
    do: Map.get(map, sort, 0)

  @doc """
  Looks up the status of a constant. Defaults to `:lex` for unknown constants.
  """
  @spec status(t(), const_id()) :: status()
  def status(%__MODULE__{status: fun}, name) when is_function(fun, 1) do
    case fun.(name) do
      s when s in [:lex, :mul] -> s
    end
  end

  def status(%__MODULE__{status: map}, name) when is_map(map),
    do: Map.get(map, name, :lex)

  @doc """
  Returns `true` if the given base sort is declared basic.
  """
  @spec basic?(t(), sort_id()) :: boolean()
  def basic?(%__MODULE__{basic_sorts: :all}, _sort), do: true

  def basic?(%__MODULE__{basic_sorts: fun}, sort) when is_function(fun, 1),
    do: fun.(sort) == true

  def basic?(%__MODULE__{basic_sorts: set}, sort), do: MapSet.member?(set, sort)

  @doc """
  Returns `true` if the 1-based argument position `i` of the constant
  identified by `name` is declared accessible.
  """
  @spec accessible?(t(), const_id(), arg_index()) :: boolean()
  def accessible?(%__MODULE__{accessible: :all}, _name, _i), do: true

  def accessible?(%__MODULE__{accessible: fun}, name, i) when is_function(fun, 2),
    do: fun.(name, i) == true

  def accessible?(%__MODULE__{accessible: set}, name, i),
    do: MapSet.member?(set, {name, i})

  @doc """
  Returns `true` if `name1` and `name2` are equivalent in `≃_F`.
  """
  @spec equiv?(t(), const_id(), const_id()) :: boolean()
  def equiv?(%__MODULE__{} = p, n1, n2), do: prec(p, n1) == prec(p, n2)

  @doc """
  Returns `true` if `name1` is strictly greater than `name2` in `≻_F`.
  """
  @spec gt?(t(), const_id(), const_id()) :: boolean()
  def gt?(%__MODULE__{} = p, n1, n2), do: prec(p, n1) > prec(p, n2)

  @doc """
  Convenience: builds parameters from a *total* precedence given as an
  ordered list, most-greater first. Each constant is placed at the rank
  corresponding to its position (so the first element in the list is
  strictly greater than the rest). Constants not listed are assigned rank
  `0` by default lookup.

  Inner lists group equivalent constants.

      iex> alias ShotTo.Parameters
      iex> p = Parameters.from_precedence_list([["f"], ["g", "h"], ["c"]])
      iex> Parameters.gt?(p, "f", "g")
      true
      iex> Parameters.equiv?(p, "g", "h")
      true
      iex> Parameters.gt?(p, "h", "c")
      true
  """
  @spec from_precedence_list([[const_id()]], keyword()) :: t()
  def from_precedence_list(tiers, opts \\ []) when is_list(tiers) do
    n = length(tiers)

    const_prec =
      tiers
      |> Enum.with_index()
      |> Enum.flat_map(fn {tier, idx} ->
        # Highest rank for index 0 (top of the list).
        rank = n - idx
        Enum.map(List.wrap(tier), fn name -> {name, rank} end)
      end)
      |> Enum.into(%{})

    new(Keyword.merge([const_precedence: const_prec], opts))
  end

  @doc """
  Best-effort validity check for `Acc` and `basic` against the types of a
  given set of constants. Returns `:ok` if no violations were found, or
  `{:error, violations}` with a list of human-readable strings describing
  the issues.

  The checks performed:

    * For each accessible `{f, i}` where `f : T_1 → … → T_n → a`, the base
      sort `a` must appear only at positive positions of `T_i` (approximated
      here as: every base sort that appears in `T_i` must be `a` or less
      than `a` in the sort precedence).
    * For each basic sort `a`, every smaller-or-equal sort appearing in an
      accessible argument type (whose host constant returns `a`) must also
      be basic.

  These are the implementation-level approximations of the conditions
  sketched in Definition 5 and following in the NCPO-LNF paper. They are
  *best-effort*: they cover the common cases without attempting the full
  positive-sort-position analysis of [2, Definition 7.2].
  """
  @spec validate(t(), %{optional(const_id()) => Type.t()}) :: :ok | {:error, [String.t()]}
  def validate(%__MODULE__{} = params, const_types) when is_map(const_types) do
    acc_violations =
      for {name, type} <- const_types,
          {arg_type, i} <- Enum.with_index(type.args, 1),
          accessible?(params, name, i),
          sort_prec(params, type.goal) < max_sort_prec_in(arg_type, params),
          do:
            "accessible argument #{i} of #{inspect(name)} has argument type " <>
              "#{type_to_iodata(arg_type)} containing a sort strictly greater than " <>
              "the return sort #{inspect(type.goal)}"

    basic_violations =
      for {name, type} <- const_types,
          basic?(params, type.goal),
          {arg_type, i} <- Enum.with_index(type.args, 1),
          accessible?(params, name, i),
          b <- sorts_in(arg_type),
          b != type.goal,
          not basic?(params, b),
          do:
            "base sort #{inspect(type.goal)} is declared basic but " <>
              "accessible argument #{i} of #{inspect(name)} contains " <>
              "non-basic sort #{inspect(b)}"

    case acc_violations ++ basic_violations do
      [] -> :ok
      violations -> {:error, Enum.uniq(violations)}
    end
  end

  defp sorts_in(%Type{goal: g, args: args}) do
    [g | Enum.flat_map(args, &sorts_in/1)]
  end

  defp max_sort_prec_in(%Type{} = t, params) do
    t
    |> sorts_in()
    |> Enum.map(&sort_prec(params, &1))
    |> Enum.max(fn -> :neg_infinity end)
  end

  defp type_to_iodata(%Type{} = t), do: Kernel.to_string(t)
end
