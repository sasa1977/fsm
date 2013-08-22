defmodule Fsm.Mixfile do
  use Mix.Project

  def project do
    [ app: :fsm,
      version: "0.0.1",
      elixir: "~> 0.10.1",
      deps: deps ]
  end

  def application do
    []
  end

  defp deps do
    []
  end
end
