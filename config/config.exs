import Config

config :lightning_css,
  version: "1.26.0",
  dev: [
    args: ~w(assets/foo.css --bundle --output-dir=static),
    watch_files: "assets",
    cd: Path.expand("../priv", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]
