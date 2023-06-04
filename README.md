# MixTester

Tiny project for testing mix tasks and anything related to project management and code generation tooling

## Features

* Real mix project management experience with `new` flags and other stuff
* Application env configuration
* Dependency list and other mix.exs configuration
* Handy and simple helpers for common commands
* ExUnit's async friendly

## Usage

```elixir
defmodule AwesomeTask do
  use ExUnit.Case, async: true

  setup do
    deps = [ {:awesome_task, path: File.cwd!()} ]
    configuration = %{{:awesome_task, :year} => 2007}

    # Creates project with `mix new my_project --sup`
    # Which has `awesome_task` as a dependency
    # And configuration where `config.exs` has
    project =
      MixTester.setup(
        name: "my_project",
        new: "--sup",
        application_env: %{
          "config" => configuration
        },
        project: [
          deps: deps
        ]
      )

    # Creates the test file
    MixTester.write_ast(project, "test/my_project_test.exs", quote do
      defmodule MyProjectTest do
        use ExUnit.Case, async: true

        test "Just works" do
          assert 2007 == AwesomeModule.what_year_is_today()
        end
      end
    end)

    # Cleanup the tmp dir
    on_exit(fn -> MixTester.cleanup(project) end)
    {:ok, project: project}
  end

  test "My awesome task", %{project: project} do
    # Run the task we are testing
    assert {_, 0} = MixTester.mix_cmd(project, "awesome")

    # Run the test written above and check if it's run successfully
    assert {_, 0} = MixTester.mix_cmd(project, "test")
  end
end
```

Check out the documentation for more practical use cases:
https://hexdocs.pm/mix_tester

## Installation

```elixir
def deps do
  [
    {:mix_tester, "~> 1.0"}
  ]
end
```
