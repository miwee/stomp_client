defmodule StompClient.Mixfile do
  use Mix.Project

  def project do
    [
      app: :stomp_client,
      version: "0.1.1",
      elixir: "~> 1.3",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:ex_doc, "~> 0.12", only: [:dev, :docs]}]
  end

  defp description do
    "STOMP client for Elixir with broker specific addons"
  end

  defp package do
    # These are the default files included in the package
    [
      name: :stomp_client,
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["miwee"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/miwee/stomp_client"}
    ]
  end
end
