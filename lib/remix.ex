defmodule Remix do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      worker(Remix.Worker, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Remix.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defmodule Worker do
    use GenServer

    def init(args) do
      {:ok, args}
    end

    def start_link do
      Process.send_after(__MODULE__, :poll_and_reload, 10000)
      GenServer.start_link(__MODULE__, %{}, name: Remix.Worker)
    end

    def handle_info(:poll_and_reload, state) do
      paths = [Path.expand("lib", "."), Path.expand("config", ".")]

      lastest_mtime = get_lastest_mtime(paths)

      if state < lastest_mtime, do: remix()

      Process.send_after(__MODULE__, :poll_and_reload, 1000)
      {:noreply, lastest_mtime}
    end

    def remix() do
      Mix.Tasks.Compile.Elixir.run(["--ignore-module-conflict"])
      # Mix.Tasks.Escript.Build.run([])
    end

    def get_lastest_mtime(dirs) when is_list(dirs) do
      dirs
      |> Enum.map(&get_modify_times/1)
      |> List.flatten()
      |> Enum.sort()
      |> Enum.reverse()
      |> List.first()
    end

    def get_modify_times(dir) do
      case File.ls(dir) do
        {:ok, files} -> get_modify_times(files, [], dir)
        _ -> []
      end
    end

    def get_modify_times([], _mtimes, _cwd), do: []
    def get_modify_times([h | tail], mtimes, cwd) do
      mtime =
        case File.dir?("#{cwd}/#{h}") do
          true -> get_modify_times("#{cwd}/#{h}")
          false -> File.stat!("#{cwd}/#{h}").mtime
        end

      get_modify_times(tail, [mtime | mtimes], cwd)
    end
  end
end
