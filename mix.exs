defmodule LightningCSS.MixProject do
  use Mix.Project

  @version "0.5.1"
  @source_url "https://github.com/samgaw/lightning_css"

  def project do
    [
      app: :lightning_css,
      version: @version,
      elixir: "~> 1.15",
      description: "A wrapper for the Lightning CSS tool.",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, inets: :optional, ssl: :optional],
      mod: {LightningCSS, []},
      env: [default: []]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:castore, ">= 0.0.0"},
      {:file_system, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:styler, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    ]
  end

  defp package do
    [
      name: "lightning_css",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "LightningCSS",
      extras: [
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      source_url: @source_url,
      source_ref: @version,
      formatters: ["html"]
    ]
  end
end
