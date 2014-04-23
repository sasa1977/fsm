defmodule Fsm.Mixfile do
  use Mix.Project

  def project do
    [
      app: :fsm,
      version: "0.0.1",
      elixir: ">= 0.13.0",
      deps: deps,
      package: [
        contributors: ["Saša Jurić"],
        licenses: ["MIT"],
        links: [{"Github", "https://github.com/sasa1977/fsm"}]
      ],
      description: """
        Finite state machine as a functional data structure.
      """
    ]
  end

  def application do
    []
  end

  defp deps do
    []
  end
end
