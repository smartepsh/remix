defmodule RemixWorker do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: Remix.Worker)
  end

  def init(_args) do
    configs = Application.get_all_env(:remix)
    interval_time = Keyword.get(configs, :interval_delay, 5000)
    watch_paths = paths(Keyword.get(configs, :watch_paths, []))
    latest_mtime = get_latest_mtime(watch_paths)

    state =
      configs
      |> Keyword.put(:watch_paths, watch_paths)
      |> Keyword.put(:latest_mtime, latest_mtime)

    Process.send_after(self(), :poll_and_reload, interval_time)

    {:ok, state}
  end

  def handle_info(:poll_and_reload, state) do
    interval_time = Keyword.get(state, :interval_time, 5000)

    latest_mtime = state |> Keyword.fetch!(:watch_paths) |> get_latest_mtime()

    if Keyword.fetch!(state, :latest_mtime) < latest_mtime, do: remix(latest_mtime)

    Process.send_after(self(), :poll_and_reload, interval_time)

    {:noreply, Keyword.put(state, :latest_mtime, latest_mtime)}
  end

  def remix(lastest_mtime) do
    IO.inspect("begin recompile!!!! lastest_mtime: #{lastest_mtime}")
    Mix.Tasks.Compile.Elixir.run(["--ignore-module-conflict"])
    # Mix.Tasks.Escript.Build.run([])
  end

  defp paths(other_paths) do
    [Path.expand("lib", "."), Path.expand("config", "."), Path.expand("deps", ".")] ++ other_paths
  end

  defp get_latest_mtime(dirs) when is_list(dirs) do
    dirs
    |> Enum.map(&get_modify_times/1)
    |> List.flatten()
    |> Enum.sort()
    |> Enum.reverse()
    |> List.first()
  end

  defp get_modify_times(dir) do
    case File.ls(dir) do
      {:ok, files} -> get_modify_times(files, [], dir)
      _ -> []
    end
  end

  defp get_modify_times([], mtimes, _cwd), do: mtimes

  defp get_modify_times([h | tail], mtimes, cwd) do
    mtime =
      case File.dir?("#{cwd}/#{h}") do
        true -> get_modify_times("#{cwd}/#{h}")
        false -> File.stat!("#{cwd}/#{h}").mtime |> NaiveDateTime.from_erl!()
      end

    get_modify_times(tail, [mtime | mtimes], cwd)
  end
end
