import Config

if Mix.env() in [:dev, :test] do
  import_config "#{Mix.env()}.exs"
end
