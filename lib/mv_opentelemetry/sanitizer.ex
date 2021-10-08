# This code is adapted from Jason.Encoder by Michal Muskala:
# https://github.com/michalmuskala/jason/blob/v1.2.2/lib/encoder.ex

defprotocol MvOpentelemetry.Sanitizer do
  @moduledoc """
  A protocol to sanitize telemetry data to remove sensitive information
  and transform it to format that can be encoded to JSON. After being passed through
  this protocol, data should have the following characteristics:

  * it is safe to store in tracing software, does not contain sensitive
    or personally identifiable data.
  * it can be later converted to JSON, which is standard storage format for
    most tracing data. Structs become bare maps.

  ## Using the `@derive` annotation

  The notations below are equivalent. You can also skip the options completely.

  ```
  defmodule MyApp.User do
    @derive {MvOpentelemetry.Sanitizer, [only: [:id, :email]]}
    @derive {MvOpentelemetry.Sanitizer, [except: [:password]]}
    defstruct [:id, :email, :password]
  end
  ```

  ## Implementing the protocol directly

  If you want to perform more complex transformations, implement the sanitize function directly.

  ```
  defimpl MvOpentelemetry.Sanitizer, for: MyApp.User do
    def sanitize(user, _opts) do
      %{id: user.id, email: Base.encode64(user.email)}
    end
  end
  ```
  """

  @doc """
  Convert a data structure into another one, that is safe to store in a tracing backend
  and can be converted to JSON. Second argument (opts) is currently unused,
  but reserved for internal use by MvOpentelemetry.Sanitizer.
  """
  @spec sanitize(t(), Access.t()) :: {:error, Exception.t()} | any()
  def sanitize(value, opts)

  @fallback_to_any true
end

defimpl MvOpentelemetry.Sanitizer, for: Any do
  defmacro __deriving__(module, struct, opts) do
    fields = fields_to_sanitize(struct, opts)
    kv = Enum.map(fields, &{&1, generated_key(&1, __MODULE__)})
    generated_values = Enum.map(fields, &{&1, generated_value(&1, __MODULE__)})

    quote do
      defimpl MvOpentelemetry.Sanitizer, for: unquote(module) do
        def sanitize(%{unquote_splicing(kv)}, opts) do
          %{unquote_splicing(generated_values)}
        end
      end
    end
  end

  defp generated_value(name, context) do
    {{:., [], [{:__aliases__, [alias: false], [:MvOpentelemetry, :Sanitizer]}, :sanitize]}, [],
     [{name, [], context}, []]}
  end

  defp generated_key(name, context) do
    {name, [generated: true], context}
  end

  defp fields_to_sanitize(struct, opts) do
    cond do
      only = Access.get(opts, :only) ->
        only

      except = Access.get(opts, :except) ->
        Map.keys(struct) -- [:__struct__ | except]

      true ->
        Map.keys(struct) -- [:__struct__]
    end
  end

  def sanitize(%_{} = struct, _opts) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: struct,
      description: """
      MvOpentelemetry.Sanitizer protocol must always be explicitly implemented.
      You can derive it:
          @derive {MvOpentelemetry.Sanitizer, only: [....]}
          defstruct ...

          @derive {MvOpentelemetry.Sanitizer, except: [....]}
          defstruct ...
      """
  end

  def sanitize(value, _opts) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: value,
      description: "MvOpentelemetry.Sanitizer protocol must always be explicitly implemented"
  end
end

defimpl MvOpentelemetry.Sanitizer, for: Atom do
  def sanitize(atom, _), do: atom
end

defimpl MvOpentelemetry.Sanitizer, for: Integer do
  def sanitize(integer, _opts), do: integer
end

defimpl MvOpentelemetry.Sanitizer, for: Float do
  def sanitize(float, _opts), do: float
end

defimpl MvOpentelemetry.Sanitizer, for: List do
  def sanitize(list, _opts), do: sanitize_loop(list, [])

  defp sanitize_loop([head | tail], acc) do
    first = MvOpentelemetry.Sanitizer.sanitize(head, [])
    sanitize_loop(tail, [first | acc])
  end

  defp sanitize_loop([], acc), do: Enum.reverse(acc)
end

defimpl MvOpentelemetry.Sanitizer, for: Map do
  def sanitize(map, _opts), do: map |> Map.to_list() |> sanitize_loop([])

  defp sanitize_loop([{key, value} | tail], acc) do
    sanitized_key = MvOpentelemetry.Sanitizer.sanitize(key, [])
    sanitized_value = MvOpentelemetry.Sanitizer.sanitize(value, [])
    sanitize_loop(tail, [{sanitized_key, sanitized_value} | acc])
  end

  defp sanitize_loop([], acc), do: Enum.into(acc, %{})
end

defimpl MvOpentelemetry.Sanitizer, for: BitString do
  def sanitize(bitstring, _opts), do: bitstring
end

defimpl MvOpentelemetry.Sanitizer, for: [Date, Time, NaiveDateTime, DateTime] do
  def sanitize(datetime, _opts), do: @for.to_iso8601(datetime)
end

defimpl MvOpentelemetry.Sanitizer, for: Decimal do
  def sanitize(decimal, _opts), do: decimal
end
