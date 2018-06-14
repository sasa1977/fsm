defmodule Fsm.Mixfile do
  use Mix.Project

  def project do
    [
      app: :fsm,
      version: "0.3.1",
      elixir: "~> 1.1",
      deps: deps(),
      package: [
        maintainers: ["Saša Jurić"],
        licenses: ["MIT"],
        links: %{Github: "https://github.com/sasa1977/fsm"}
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
