defmodule Fsm.Mixfile do
  use Mix.Project

  def project do
    [
      app: :fsm,
      version: "0.2.0",
      elixir: "~> 1.0",
      deps: deps(),
      package: [
        maintainers: ["Saša Jurić"],
        licenses: ["MIT"],
        links: %{"Github": "https://github.com/sasa1977/fsm"}
      ],
      description: "Finite state machine as a functional data structure."
    ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    []
  end
end
