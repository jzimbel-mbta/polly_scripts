defmodule PollyScriptsTest do
  use ExUnit.Case
  doctest PollyScripts

  test "greets the world" do
    assert PollyScripts.hello() == :world
  end
end
