defmodule Mix.Tasks.LightningCss.Install do
  @shortdoc "Installs lightning_css under _build"
  @moduledoc """
  Installs lightning_css under `_build`.

  ```bash
  $ mix lightning_css.install
  $ mix lightning_css.install --if-missing
  ```

  By default, it installs #{LightningCSS.Versions.latest()} but you
  can configure it in your config files, such as:

      config :lightning_css, :version, "#{LightningCSS.Versions.latest()}"

  ## Options

      * `--runtime-config` - load the runtime configuration
        before executing command

      * `--if-missing` - install only if the given version
        does not exist
  """

  use Mix.Task

  @compile {:no_warn_undefined, Mix}

  @impl true
  def run(args) do
    valid_options = [runtime_config: :boolean, if_missing: :boolean]

    case OptionParser.parse_head!(args, strict: valid_options) do
      {opts, []} ->
        if opts[:runtime_config], do: Mix.Task.run("app.config")

        if opts[:if_missing] && latest_version?() do
          :ok
        else
          # credo:disable-for-next-line
          if function_exported?(Mix, :ensure_application!, 1) do
            # ensure_application! ensures that the given application and its dependencies are availble
            # in the path
            Mix.ensure_application!(:inets)
            Mix.ensure_application!(:ssl)
          end

          LightningCSS.Installer.install()
        end

      {_, _} ->
        Mix.raise("""
        Invalid arguments to lightning_css.install, expected one of:

            mix lightning_css.install
            mix lightning_css.install --runtime_config dev
            mix lightning_css.install --if-missing
        """)
    end
  end

  defp latest_version? do
    version = LightningCSS.Versions.to_use()
    match?({:ok, ^version}, LightningCSS.Versions.bin())
  end
end
