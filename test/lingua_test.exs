defmodule LinguaTest do
  use ExUnit.Case
  doctest Lingua

  test "returns version" do
    assert Lingua.version() == "0.1.0"
  end
end
