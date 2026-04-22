defmodule ShotTo.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/jcschuster/ShotTo"

  def project do
    [
      app: :shot_to,
      description: description(),
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:shot_ds, "~> 1.0"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    An Elixir implementation of NCPO-LNF (the βη-long-normal Computability Path
    Order of Niederhauser and Middeldorp) for ordering terms in Church's simple
    type theory as represented by the `shot_ds` library.

    The order decides, given two terms s and t and a choice of ordering
    parameters (sort/constant precedences, symbol statuses, basic sorts,
    accessibility), whether s > t in NCPO-LNF. It is intended for use as an
    orientation order in higher-order tableau and other theorem-proving
    settings that need a concrete decision procedure rather than an SMT
    constraint.
    """
  end
end
