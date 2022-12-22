defmodule MvOpentelemetryHarness.BroadwayDummy do
  use Broadway

  def start_link() do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [module: {Broadway.DummyProducer, []}, concurrency: 1],
      processors: [default: [concurrency: 1]],
      batchers: [default: [concurrency: 1]]
    )
  end

  def test_message(message) do
    Broadway.test_message(__MODULE__, message)
  end

  def handle_message(:default, message, _context) do
    message
  end

  def handle_batch(:default, messages, _batch_info, _context) do
    messages
  end
end
