defmodule Spotter.MixProject do
  use Mix.Project

  @version "0.5.0"

  def project do
    [
      app: :spotter,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:amqp, :confex]
    ]
  end

  defp description do
    """
    Package for implementing AMQP workers and middlewares
    """
  end

  defp deps do
    [
      {:confex, "~> 3.3.1"},
      {:amqp, "~> 1.0"},
      {:earmark, "~> 1.2.6", only: :dev},
      {:ex_doc, "~> 0.19.1", only: :dev},
      {:ranch_proxy_protocol, "~> 2.0", override: true}
    ]
  end

  defp package do
    [
       name: :spotter,
       files: ["lib", "mix.exs", "README.md", "LICENSE"],
       maintainers: ["Valeryi Savich"],
       licenses: ["BSD 3-clause"],
       links: %{"GitHub" => "https://github.com/OpenMatchmaking/spotter"}
    ]
  end
end
