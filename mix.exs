defmodule MixTester.MixProject do
  use Mix.Project

  @version "1.1.0"

  @description """
  Tiny tool for project testing
  """

  def project do
    [
      app: :mix_tester,
      deps: deps(),
      description: @description,
      docs: docs(),
      elixir: "~> 1.14",
      name: "MixTester",
      package: package(),
      source_url: "https://github.com/hissssst/mix_tester",
      start_permanent: Mix.env() == :prod,
      version: @version
    ]
  end

  def application do
    []
  end

  defp package do
    [
      description: @description,
      licenses: ["BSD-2-Clause"],
      files: [
        "lib",
        "mix.exs",
        "README.md",
        ".formatter.exs"
      ],
      maintainers: [
        "Georgy Sychev"
      ],
      links: %{
        GitHub: "https://github.com/hissssst/mix_tester",
        Changelog: "https://github.com/hissssst/mix_tester/blob/master/CHANGELOG.md"
      }
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.0", only: :dev, runtime: false},
      {:credo, "~> 1.5", only: :dev, runtime: false},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:sourceror, "~> 0.12"}
    ]
  end
end
