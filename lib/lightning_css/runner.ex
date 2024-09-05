defmodule LightningCSS.Runner do
  @moduledoc false

  use GenServer

  require Logger

  @type init_args :: %{
          profile: atom(),
          extra_args: [String.t()],
          watch: boolean()
        }

  @spec start_link(args :: init_args) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @spec init(args :: init_args) :: {:ok, any()}
  def init(%{profile: profile, extra_args: _, watch: watch} = args) do
    config = LightningCSS.Configuration.config_for!(profile)
    cd = Keyword.get(config, :cd, File.cwd!())

    watcher_pid =
      case {watch, config[:watch_files]} do
        {true, glob} when is_binary(glob) ->
          dirs = expand_glob(Path.join(cd, glob))
          {:ok, watcher_pid} = FileSystem.start_link(dirs: dirs)
          FileSystem.subscribe(watcher_pid)
          watcher_pid

        _ ->
          nil
      end

    args =
      args |> Map.put(:config, config) |> Map.put(:cd, cd) |> Map.put(:watcher_pid, watcher_pid)

    gen_server_pid = self()
    args = Map.put(args, :gen_server_pid, gen_server_pid)

    %{pid: process_pid} =
      Task.async(fn ->
        Logger.info("Running Lightning CSS")
        __MODULE__.run_lightning_css(args)
      end)

    args = Map.put(args, :process_pid, process_pid)

    {:ok, args}
  end

  defp expand_glob(watch_files) do
    watch_files
    |> List.wrap()
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.uniq()
  end

  def run_lightning_css(%{config: config, extra_args: extra_args, cd: cd, gen_server_pid: gen_server_pid}) do
    args = config[:args] || []

    if args == [] and extra_args == [] do
      raise "no arguments passed to lightning_css"
    end

    opts = [
      cd: cd,
      env: config[:env] || %{},
      into: IO.stream(:stdio, :line),
      stderr_to_stdout: true
    ]

    command_string =
      Enum.join([Path.relative_to_cwd(LightningCSS.Paths.bin())] ++ args ++ extra_args, " ")

    Logger.debug("Command: #{command_string}", opts)

    exit_status =
      LightningCSS.Paths.bin()
      |> System.cmd(args ++ extra_args, opts)
      |> elem(1)

    Logger.debug("Command completed with exit status #{exit_status}")
    send(gen_server_pid, {:lightning_css_exited, exit_status})
  end

  def handle_info({:file_event, _watcher_pid, {_path, _events}}, state) do
    %{pid: process_pid} =
      Task.async(fn ->
        Logger.info("Changes detected. Running Lightning CSS")
        __MODULE__.run_lightning_css(state)
      end)

    state = Map.put(state, :process_pid, process_pid)
    {:noreply, state}
  end

  def handle_info({:file_event, watcher_pid, :stop}, %{watcher_pid: watcher_pid} = state) do
    {:stop, :normal, state}
  end

  def handle_info({:lightning_css_exited, exit_status}, %{watch: watch} = state) do
    case {watch, exit_status} do
      {true, 0} ->
        {:noreply, state}

      {false, 0} ->
        {:stop, :normal, state}

      {true, _status} ->
        {:no_reply, state}

      {false, status} ->
        {:stop, {:error_and_no_watch, status}, state}
    end
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def terminate(:normal, _state) do
    :ok
  end

  def terminate(_, _) do
    :ok
  end
end
