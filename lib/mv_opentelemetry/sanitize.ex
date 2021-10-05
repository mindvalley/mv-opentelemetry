defmodule MvOpentelemetry.Sanitize do
  @moduledoc false

  def sanitize(value), do: sanitize(value, [])
  def sanitize(value, opts), do: MvOpentelemetry.Sanitizer.sanitize(value, opts)

  def sanitize!(value), do: sanitize!(value, [])

  def sanitize!(value, opts) do
    case sanitize(value, opts) do
      {:error, error} -> raise error
      value -> value
    end
  end
end
