defmodule LightningCSS do
  @moduledoc """
  `lightning_css` is an Elixir package to integrate [Lightning CSS](https://lightningcss.dev/) into an Elixir project.

  ## Usage
  After installing the package, you'll have to configure it in your project:

  ```elixir
  # config/config.exs
  config :lightning_css,
    version: "1.22.1",
    default: [
      args: ~w(assets/css/app.css --bundle --output-file=priv/static/styles/bundle.css),
      watch_files: "assets/css/**/*.css",
      cd: Path.expand("..", __DIR__),
      env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
    ]
  ```

  ### Configuration options

  - **version:** Indicates the version that the package will download and use. When absent, it defaults to the value of `@latest_version` at [`lib/lightning_css.ex`](./lib/lightning_css.ex).
  - **profiles:** Additional keys in the configuration keyword list represent profiles. Profiles are a combination of attributes the Lightning CSS can be executed with. You can indicate the profile to use when invoking the Mix task by using the `--profile` flag, for example `mix lightning_css --profile dev`. A profile is represented by a keyword list with the following attributes:
    - **args:** An list of strings representing the arguments that will be passed to the Lightning CSS executable.
    - **watch_files (optional):** A glob pattern that will be used when Lightning CSS is invoked with `--watch` to match the file changes against it.
    - **cd (optional):** The directory from where Lightning CSS is executed. When absent, it defaults to the project's root directory.
    - **env (optional):** A set of environment variables to make available to the Lightning CSS process.

  ### Phoenix

  If you are using the Phoenix framework, we recommend doing an integration similar to the one Phoenix proposes by default for Tailwind and ESBuild.

  After adding the dependency and configuring it as described above with at least one profile, adjust your app's endpoint configuration to add a new watcher:

  ```elixir
  config :my_app, MyAppWeb.Endpoint,
    # ...other attributes
    watchers: [
      # :default is the name of the profile. Update it to match yours.
      css: {LightningCSS, :install_and_run, [:default, ~w(), [watch: true]]}
    ]
  ```

  Then update the `aliases` of your project's `mix.exs` file:

  ```elixir
  defp aliases do
    [
      # ...other aliases
      "assets.setup": [
        # ...other assets.setup tasks
        "lightning_css.install --if-missing"
      ],
      "assets.build": [
        # ...other assets.build tasks
        "lightning_css default",
      ],
      "assets.deploy": [
        # ...other deploy tasks
        "lightning_css default",
      ]
    ]
  end
  ```
  """

  use Application

  require Logger

  def start(_, _) do
    unless LightningCSS.Versions.configured() do
      Logger.warning("""
      lightning_css version is not configured. Please set it in your config files:

          config :lightning_css, :version, "#{LightningCSS.Versions.latest()}"
      """)
    end

    configured_version = LightningCSS.Versions.to_use()

    case LightningCSS.Versions.bin() do
      {:ok, ^configured_version} ->
        :ok

      {:ok, version} ->
        Logger.warning("""
        Outdated lightning_css version. Expected #{configured_version}, got #{version}. \
        Please run `mix lightning_css.install` or update the version in your config files.\
        """)

      :error ->
        :ok
    end

    Supervisor.start_link([], strategy: :one_for_one, name: __MODULE__.Supervisor)
  end

  @doc """
  Runs the given command with `args`.

  The given args will be appended to the configured args.
  The task output will be streamed directly to stdio. It returns the status of the underlying call.
  """
  @spec run(atom(), list(), Keyword.t()) :: :ok | {:error, {:exited, integer()}}
  def run(profile, extra_args, opts) when is_atom(profile) and is_list(extra_args) do
    watch = Keyword.get(opts, :watch, false)

    id =
      ([profile] ++ extra_args ++ [watch])
      |> Enum.map_join("_", &to_string/1)
      |> String.to_atom()

    ref =
      __MODULE__.Supervisor
      |> Supervisor.start_child(
        Supervisor.child_spec(
          {LightningCSS.Runner,
           %{
             profile: profile,
             extra_args: extra_args,
             watch: watch
           }},
          id: id,
          restart: :transient
        )
      )
      |> case do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end
      |> Process.monitor()

    receive do
      {:DOWN, ^ref, _, _, {:error_and_no_watch, code}} ->
        {:error, {:exited, code}}

      _ ->
        :ok
    end
  end

  @doc """
  Installs, if not available, and then runs `lightning_css`.

  Returns the same as `run/2`.
  """
  @spec install_and_run(atom(), list(), Keyword.t()) :: integer()
  def install_and_run(profile, args, opts \\ []) do
    File.exists?(LightningCSS.Paths.bin()) || start_unique_install_worker()

    run(profile, args, opts)
  end

  defp start_unique_install_worker do
    ref =
      __MODULE__.Supervisor
      |> Supervisor.start_child(
        Supervisor.child_spec({Task, &LightningCSS.Installer.install/0},
          restart: :transient,
          id: __MODULE__.Installer
        )
      )
      |> case do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end
      |> Process.monitor()

    receive do
      {:DOWN, ^ref, _, _, _} -> :ok
    end
  end
end
