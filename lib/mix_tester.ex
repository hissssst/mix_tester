defmodule MixTester do
  @moduledoc """
  Small tool to automate mix project creation specifically for testing.
  """

  alias MixTester.AST

  defmodule Project do
    @moduledoc """
    Structure which contains path to project root directory
    and a name of the project
    """
    defstruct [:root, :name]
    @type t :: %__MODULE__{root: Path.t(), name: String.t()}
  end

  @typedoc "Output and exit code returned by executed command"
  @type command_result :: {binary(), non_neg_integer()}

  @type application_env :: %{
          (config_file :: String.t()) => %{{app :: atom(), key :: atom()} => value :: any()}
        }

  @typedoc """
  - `:name` (string) — Name of the mix project (doesn't have to be unique)
  - `:new` (string) — String of options for `mix new name`
  - `:application_env` (application_env) — A configuration for the project
  - `:project` - A kv to override what's written in `mix.exs`'s `project` function
  - `:application` - A kv to override what's written in `mix.exs`'s `application` function
  """
  @type setup_option ::
          {:name, String.t()}
          | {:new, String.t()}
          | {:application_env, application_env()}

  @doc """
  Sets up the mix project for testing
  """
  @spec setup([setup_option()]) :: Project.t()
  def setup(opts \\ []) do
    unique_dir = Integer.to_string(:erlang.unique_integer([:positive]))
    tmp_project_dir = Path.join(tester_root(), unique_dir)

    if File.exists?(tmp_project_dir) do
      setup(opts)
    else
      do_setup(tmp_project_dir, opts)
    end
  end

  defp do_setup(tmp_project_dir, opts) do
    File.mkdir_p!(tmp_project_dir)
    name = opts[:name] || "test_project"
    new_opts = "#{name} #{opts[:new] || ""}"
    cmd!("mix new " <> new_opts, cd: tmp_project_dir)

    [project_dirname] = File.ls!(tmp_project_dir)
    project_root = Path.join(tmp_project_dir, project_dirname)
    project = %Project{root: project_root, name: name}

    prepare_mixexs(project, opts)
    prepare_config(project, opts[:application_env])

    if Code.ensure_loaded?(ExUnit) do
      try do
        apply(ExUnit, :after_suite, [
          fn _ ->
            cleanup(project)
          end
        ])
      rescue
        _ -> :ok
      end
    end

    project
  end

  defp prepare_mixexs(project, opts) do
    at_ast(project, "mix.exs", fn ast ->
      {:defp, _, [{:deps, _, _}, [{_, body}]]} =
        AST.find(ast, fn
          {:defp, _, [{:deps, _, _}, _]} -> true
          _ -> false
        end)

      deps =
        body
        |> eval()
        |> Macro.escape()

      Macro.postwalk(ast, fn
        {:defp, _, [{:deps, _, _}, _]} ->
          nil

        {:deps, _, []} ->
          deps

        {:def, meta, [{key, _, _} = p, [{thedo, body}]]} when key in ~w[project application]a ->
          kv =
            body
            |> eval()
            |> Keyword.merge(opts[key] || [])
            |> Macro.escape()

          {:def, meta, [p, [{thedo, kv}]]}

        other ->
          other
      end)
    end)
  end

  defp prepare_config(_project, nil), do: :ok

  defp prepare_config(project, application_env) do
    {config, application_env} = Map.pop(application_env, "config", [])

    write_ast(
      project,
      "config/config.exs",
      quote do
        import Config

        unquote_splicing(
          for {{app, key}, value} <- config do
            quote do: config(unquote(app), unquote(key), unquote(Macro.escape(value)))
          end
        )

        import_config "#{config_env()}.exs"
      end
    )

    for {config_file, config} <- application_env do
      write_ast(
        project,
        "config/#{config_file}.exs",
        quote do
          import Config

          unquote_splicing(
            for {{app, key}, value} <- config do
              quote do: config(unquote(app), unquote(key), unquote(Macro.escape(value)))
            end
          )
        end
      )
    end
  end

  @doc """
  Deletes project
  """
  @spec cleanup(Project.t()) :: :ok
  def cleanup(%Project{root: root}) do
    root
    |> Path.join("..")
    |> Path.expand()
    |> File.rm_rf!()

    :ok
  end

  @doc """
  Executes shell command in the project
  """
  @spec sh(Project.t(), command :: String.t(), Keyword.t()) :: command_result()
  def sh(%Project{root: root}, command_string, opts \\ []) do
    opts = Keyword.update(opts, :cd, root, &Path.join(root, &1))
    System.cmd("sh", ["-c", command_string], opts)
  end

  @doc """
  Executes command in project root
  """
  @spec cmd(Project.t(), String.t(), [String.t()], Keyword.t()) :: command_result()
  def cmd(%Project{root: root}, command, args, opts \\ []) do
    opts = Keyword.update(opts, :cd, root, &Path.join(root, &1))
    System.cmd(command, args, opts)
  end

  @doc """
  Executes mix command in project root
  """
  @spec mix_cmd(Project.t(), String.t(), [String.t()], Keyword.t()) :: command_result()
  def mix_cmd(%Project{root: root}, command, args \\ [], opts \\ []) do
    opts = Keyword.update(opts, :cd, root, &Path.join(root, &1))
    System.cmd("mix", [command | args], opts)
  end

  @doc """
  Reads the existing file from project
  """
  @spec read(Project.t(), Path.t()) :: binary()
  def read(project, filename) do
    project
    |> expand(filename)
    |> File.read!()
  end

  @doc """
  Writes a file in the project
  """
  @spec write(Project.t(), Path.t(), iodata(), list()) :: :ok
  def write(project, filename, content, modes \\ []) do
    expanded = expand(project, filename)
    do_mkdir_p(expanded)
    File.write!(expanded, content, [:sync | modes])
  end

  @doc """
  Writes an AST in the file
  """
  @spec write_ast(Project.t(), Path.t(), Macro.t(), list()) :: :ok
  def write_ast(project, filename, ast, modes \\ []) do
    content =
      ast
      |> Sourceror.to_string()
      |> Code.format_string!()

    write(project, filename, content, modes)
  end

  @doc """
  Changes Elixir AST of file
  """
  @spec at_ast(Project.t(), Path.t(), (Macro.t() -> Macro.t())) :: :ok
  def at_ast(project, filename, func) do
    content = read(project, filename)
    ast = Sourceror.parse_string!(content)
    new_ast = func.(ast)

    content =
      new_ast
      |> Sourceror.to_string()
      |> Code.format_string!()

    write(project, filename, content)
  end

  @doc """
  Checks if path exists in the project
  """
  @spec exists?(Project.t(), Path.t()) :: boolean()
  def exists?(project, filename) do
    File.exists?(expand(project, filename))
  end

  @doc """
  Expands path from relative path of the project
  """
  @spec expand(Project.t(), Path.t()) :: Path.t()
  def expand(%Project{root: root}, filename) do
    Path.expand(filename, root)
  end

  @doc """
  Create a directory for specified file.
  If you want to just create a directory, don't forget to add trailing slash.
  """
  @spec mkdir_p(Project.t(), Path.t()) :: Path.t()
  def mkdir_p(%Project{root: root}, filename) do
    do_mkdir_p(Path.expand(filename, root))
    filename
  end

  defp do_mkdir_p(expanded_filename) do
    File.mkdir_p!(Path.dirname(expanded_filename))
  end

  # Helpers

  defp tester_root do
    Path.join(System.tmp_dir!(), "mix_tester")
  end

  defp cmd!(string, opts) do
    [command | args] =
      string
      |> String.split()
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case System.cmd(command, args, opts) do
      {output, 0} ->
        output

      {output, code} ->
        raise "Command #{string} failed with (exit code #{code}) #{output}"
    end
  end

  defp eval(quoted) do
    {data, _} = Code.eval_quoted(quoted)
    data
  end
end
