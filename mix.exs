defmodule ShotTo.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/jcschuster/ShotTo"

  def project do
    [
      app: :shot_to,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: @source_url,
      description: description(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:shot_ds, "~> 1.2"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    An Elixir implementation of NCPO-LNF (the βη-long-normal Computability Path
    Order of Niederhauser and Middeldorp) for ordering terms in Church's simple
    type theory as represented by the `shot_ds` library.
    """
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "examples/demo.livemd"
      ],
      source_url: @source_url,
      source_ref: "v#{@version}",
      before_closing_head_tag: &before_closing_head_tag/1,
      before_closing_body_tag: &before_closing_body_tag/1
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Johannes Schuster"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(lib LICENSE mix.exs README.md)
    ]
  end

  defp before_closing_head_tag(:html) do
    """
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.28/dist/katex.min.css">
    """
  end

  defp before_closing_head_tag(_), do: ""

  defp before_closing_body_tag(:html) do
    """
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.28/dist/katex.min.js" integrity="sha384-+W9OcrYK2/bD7BmUAk+xeFAyKp0QjyRQUCxeU31dfyTt/FrPsUgaBTLLkVf33qWt" crossorigin="anonymous"></script>
    <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.28/dist/contrib/auto-render.min.js" integrity="sha384-hCXGrW6PitJEwbkoStFjeJxv+fSOOQKOPbJxSfM6G5sWZjAyWhXiTIIAmQqnlLlh" crossorigin="anonymous"></script>

    <script>
      document.addEventListener("DOMContentLoaded", function() {
        var renderMath = function() {
          if (window.renderMathInElement) {
            renderMathInElement(document.body, {
              delimiters: [
                {left: "$$", right: "$$", display: true},
                {left: "$", right: "$", display: false}
              ]
            });
          }
        };

        var attempts = 0;
        var initInterval = setInterval(function() {
          if (window.renderMathInElement) {
            renderMath();
            clearInterval(initInterval);
          } else if (attempts > 20) {
            clearInterval(initInterval);
          }
          attempts++;
        }, 100);

        var observer = new MutationObserver(function(mutations) {
          observer.disconnect();
          renderMath();
          observer.observe(document.body, { childList: true, subtree: true });
        });

        observer.observe(document.body, { childList: true, subtree: true });
      });
    </script>
    """
  end

  defp before_closing_body_tag(_), do: ""
end
