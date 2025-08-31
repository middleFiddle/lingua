defmodule Lingua.MixProject do
  use Mix.Project

  def project do
    [
      app: :lingua,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description:
        "The AI-Powered Translation Build Tool - Generate professional translations at build time, not runtime",
      package: package(),
      escript: [main_module: Lingua.CLI],

      # Release configuration
      releases: [
        lingua: [
          include_executables_for: [:unix],
          applications: [lingua: :permanent],
          steps: [:assemble, :tar]
        ]
      ],

      # Documentation
      name: "Lingua",
      docs: [
        main: "Lingua",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto, :ssl, :inets]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bumblebee, "~> 0.6.0", optional: true},
      {:nx, "~> 0.10.0", optional: true},
      {:exla, "~> 0.10.0", optional: true},
      {:jason, "~> 1.4"},
      {:req, "~>0.5.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      files: ~w(lib priv .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/yourorg/lingua"}
    ]
  end
end
