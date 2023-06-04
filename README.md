# MixTester

Tiny project for testing elixir dependencies

## Features

* ExUnit's async friendly
* Helpers for common commands

## Usage

```elixir
defmodule MyTest do
  use ExUnit.Case, async: true

  setup do
    project =
      MixTester.setup(name: "my_project", application_env: %{
        # Set the configuration in `config.exs`
        "config" => %{{:my_project, :config_key} => :config_value},

        # Set the configuration in `dev.exs`
        "dev" => %{{:my_project, :config_key} => :dev_value}
      })

    on_exit(fn ->
      cleanup(project)
    end)

    {:ok, project: project}
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
