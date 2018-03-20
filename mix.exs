defmodule Spotter.MixProject do
  use Mix.Project

  @version "0.1.2"

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
    Middleware for message queue-based microservices
    """
  end

  defp deps do
    [
      {:confex, "~> 3.3.0"},
      {:amqp, "~> 1.0.2"},
      {:earmark, "~> 1.2.0", only: :dev},
      {:ex_doc, "~> 0.18", only: :dev}
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
