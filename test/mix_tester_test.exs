defmodule MixTesterTest do
  use ExUnit.Case
  doctest MixTester, import: true, except: [cleanup_all: 0, expand: 2]

  test "Creates and deletes the project" do
    project = MixTester.setup()
    assert MixTester.exists?(project, "mix.exs")

    MixTester.cleanup(project)
    refute MixTester.exists?(project, "mix.exs")
  end

  describe "Helpers work" do
    test "Writing works" do
      project = MixTester.setup(name: "example")
      on_exit(fn -> MixTester.cleanup(project) end)

      MixTester.mix_cmd(project, "deps.get")

      MixTester.write(project, "lib/example.ex", """
      defmodule Example do
        def hello(), do: :world
      end
      """)

      assert """
             defmodule Example do
               def hello(), do: :world
             end
             """ == MixTester.read(project, "lib/example.ex")

      assert {_, 0} = MixTester.mix_cmd(project, "test")
    end

    test "Deps installation works" do
      project = MixTester.setup(project: [deps: [pathex: "~> 2.5"]], name: "example")
      on_exit(fn -> MixTester.cleanup(project) end)

      MixTester.mix_cmd(project, "deps.get")

      MixTester.write_ast(
        project,
        "lib/example.ex",
        quote do
          defmodule Example do
            use Pathex

            def hello do
              Pathex.view!([hello: :world], path(:hello))
            end
          end
        end
      )

      assert {_, 0} = MixTester.mix_cmd(project, "test")
    end

    test "Application configuration works" do
      project =
        MixTester.setup(
          name: "example",
          application_env: %{
            "config" => %{{:example, :key} => :config_value},
            "dev" => %{{:example, :key} => :dev_value},
            "test" => %{{:example, :key} => :test_value}
          }
        )

      on_exit(fn -> MixTester.cleanup(project) end)

      MixTester.mix_cmd(project, "deps.get")

      MixTester.write_ast(
        project,
        "test/example_test.exs",
        quote do
          defmodule ExampleTest do
            use ExUnit.Case

            test "Configuration works" do
              assert :test_value == Application.get_env(:example, :key)
            end
          end
        end
      )

      assert {_, 0} = MixTester.mix_cmd(project, "test")

      MixTester.write_ast(
        project,
        "test/example_test.exs",
        quote do
          defmodule ExampleTest do
            use ExUnit.Case

            test "Configuration works" do
              assert :dev_value == Application.get_env(:example, :key)
            end
          end
        end
      )

      assert {_, 0} = MixTester.mix_cmd(project, "test", [], env: [{"MIX_ENV", "dev"}])
    end
  end
end
