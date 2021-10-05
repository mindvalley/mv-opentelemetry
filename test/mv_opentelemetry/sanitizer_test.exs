defmodule MvOpentelemetry.SanitizerTest do
  use ExUnit.Case

  alias MvOpentelemetry.Sanitizer

  test "#sanitize/2 sanitizes data" do
    test_data = [
      {%MvOpentelemetry.DerivedStruct{email: "test@test.com"},
       %{email: "test@test.com", id: nil, name: nil}},
      {%MvOpentelemetry.ExceptStruct{email: "test@test.com"}, %{id: nil, name: nil}},
      {%MvOpentelemetry.OnlyStruct{email: "test@test.com"}, %{email: "test@test.com"}},
      {%MvOpentelemetry.DerivedViaProtocolStruct{email: "protocol@test.com"},
       %{email: "protocol@test.com", id: nil, name: nil}}
    ]

    for {input, expected_output} <- test_data do
      assert Sanitizer.sanitize(input, []) == expected_output
    end
  end

  test "#sanitize/2 raises on custom o non-implementation" do
    value = %MvOpentelemetry.NotImplementedStruct{email: "protocol@test.com"}

    assert_raise Protocol.UndefinedError,
                 ~r/MvOpentelemetry.Sanitizer protocol must always be explicitly implemented./,
                 fn ->
                   Sanitizer.sanitize(value, [])
                 end
  end
end
