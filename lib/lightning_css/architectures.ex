defmodule LightningCSS.Architectures do
  @moduledoc false

  def target do
    case :os.type() do
      {:win32, _} ->
        target(:win32)

      {:unix, :darwin} ->
        target(:darwin)

      {:unix, :linux} ->
        target(:linux)

      _ ->
        unsupported_os()
    end
  end

  defp target(:win32) do
    only_64bits()

    "win32-x64-msvc"
  end

  defp target(:darwin) do
    only_64bits()

    case arch_info() do
      {"arm", _} -> "darwin-arm64"
      {"aarch64", _} -> "darwin-arm64"
      {"x86_64", _} -> "darwin-x64"
      _ -> unsupported_arch()
    end
  end

  defp target(:linux) do
    {arch, toolchain} = arch_info()

    if arch == "arm" && toolchain == "gnueabihf" do
      "linux-arm-gnueabihf"
    else
      only_64bits()

      arch =
        case arch do
          "amd64" -> "x64"
          "x86_64" -> "x64"
          "arm" -> "arm64"
          "arm64" -> "arm64"
          _ -> unsupported_arch()
        end

      unless toolchain in ~w[gnu musl] do
        unsupported_arch()
      end

      "linux-#{arch}-#{toolchain}"
    end
  end

  defp arch_info do
    arch_info =
      :system_architecture
      |> :erlang.system_info()
      |> to_string()
      |> String.split("-")

    {List.first(arch_info), List.last(arch_info)}
  end

  defp only_64bits do
    unless :erlang.system_info(:wordsize) == 8 do
      raise("lightning_css is not available for a non 64-bit operating system")
    end
  end

  defp unsupported_os do
    raise("lightning_css is not available for operating system: #{inspect(:os.type())}")
  end

  defp unsupported_arch do
    raise("lightning_css is not available for architecture: #{:erlang.system_info(:system_architecture)}")
  end
end
