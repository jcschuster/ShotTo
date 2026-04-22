# ShotTo

**ShotTo** is an Elixir implementation of NCPO-LNF — the βη-long-normal
Computability Path Order of Niederhauser and Middeldorp, _NCPO goes
Beta-Eta-Long Normal Form_ (2025) — for ordering terms of Church's simple
type theory as represented by the [`shot_ds`](https://hexdocs.pm/shot_ds/)
library.

`ShotTo` is developed at the [University of Bamberg](https://www.uni-bamberg.de/en/),
[Chair for AI Systems Engineering](https://www.uni-bamberg.de/en/aise/),
primarily as an orientation order for a higher-order tableau prover.

## What it does

Given two terms _s_ and _t_ in βη-long normal form and a choice of
_ordering parameters_, `ShotTo` decides the boolean predicate
**s >¹_τ t** of Definition 8 of the paper. It is a drop-in decision
procedure rather than an SMT-constraint generator: the parameters
(precedences, statuses, accessibility, basicness) are fixed inputs
supplied by the caller, not unknowns.

```elixir
import ShotDs.Hol.Dsl
import ShotDs.Hol.Definitions
alias ShotDs.Stt.TermFactory, as: TF
alias ShotTo.Parameters

params = Parameters.new(const_precedence: %{"f" => 1, "c" => 0})
f  = TF.make_const_term("f", Type.new(:i, :i))
c  = TF.make_const_term("c", type_i())
fc = app(f, c)

ShotTo.gt?(fc, c, params)       # => true   (by ⟨F▷⟩: c is a subterm of f(c))
ShotTo.gt?(c, fc, params)       # => false
ShotTo.compare(fc, c, params)   # => :greater
```

## API surface

### `ShotTo`

- `gt?(s_id, t_id, params \\ default)` — decides `s >¹_τ t`.
- `geq?(s_id, t_id, params \\ default)` — reflexive closure.
- `compare(s_id, t_id, params \\ default)` — returns `:greater`,
  `:less`, `:equal`, or `:incomparable`.

### `ShotTo.Parameters`

A struct with fields

- `sort_precedence` — map or function on atoms giving the rank of each
  base sort (higher is greater in ≻_S).
- `const_precedence` — map or function on constant identifiers giving
  the rank in ≻_F.
- `status` — map or function assigning `:lex` or `:mul` to each
  constant.
- `basic_sorts` — `:all`, a MapSet, or a predicate.
- `accessible` — `:all`, a MapSet of `{name, index}` pairs, or a binary
  predicate.

Helpers:

- `Parameters.new/1`, `Parameters.from_precedence_list/2`, and lookup
  functions `prec/2`, `sort_prec/2`, `status/2`, `basic?/2`,
  `accessible?/3`, `equiv?/3`, `gt?/3`.
- `Parameters.validate/2` for a best-effort sanity-check against a map
  of constant types.

Defaults are permissive: all sorts equivalent and basic, all positions
accessible, all constants equivalent with `:lex` status. Under these
defaults NCPO-LNF reduces to the simple subterm order plus
lexicographic-in-the-same-head comparison, which is rarely what you
want; at a minimum supply a `const_precedence`.

## Two notes on the paper and the reference implementation

While implementing I ran into two small points where the implementation
had to deviate slightly from a literal reading of the NCPO-LNF paper and
its Haskell prototype
([`niedjoh/hrsterm`](https://github.com/niedjoh/hrsterm)):

1. The paper's `⟨F=lex⟩` clause reads

    > ∀j > i. f(t̄) >^{b,X} **t_j**

    but the Haskell reference — and the standard RPO lexicographic
    extension — uses **u_j** (the residual tail of the right-hand side).
    `ShotTo` follows the reference.

2. The Haskell `ncpoMul` does not reject the "equal multisets" case:
   for identical multisets both symmetric differences are empty and
   `and []` vacuously holds, yielding `true`. Inside the reference's
   SMT-constraint pipeline this appears to be benign because
   precedence-strictness rules it out at the call sites; for a boolean
   decision procedure the check needs to be made explicit. `ShotTo`
   adds an `ss \ ts ≠ ∅` strictness test.

Both are flagged in the module docs of `ShotTo.NCPO`.

## Status and caveats

- NCPO-LNF is not (yet known to be) **transitive**. Use `ShotTo` to
  decide orientation of one pair at a time, not as a comparator for
  sorting or for building total orders on sets of terms.
- `ShotTo.Parameters.validate/2` is a best-effort check of the
  accessibility and basicness conditions (Definition 5 of the paper). A
  sound but conservative choice is to leave `accessible: :all` and
  `basic_sorts: :all` — the conditions then hold vacuously.
- Every lambda opening allocates a fresh ShotDs free variable. Callers
  concerned with global ETS growth should wrap their comparisons in
  `ShotDs.Stt.TermFactory.with_scratchpad!/1`; fresh variables
  generated during the comparison will then die with the scratchpad.

## Installation

Add `shot_to` to your dependencies:

```elixir
def deps do
  [
    {:shot_to, "~> 0.1"}
  ]
end
```

## License

MIT.
