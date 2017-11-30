defmodule MarathonEventExporterTest do
  use ExUnit.Case
  doctest MarathonEventExporter

  test "greets the world" do
    assert MarathonEventExporter.hello() == :world
  end
end
