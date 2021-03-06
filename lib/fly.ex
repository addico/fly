defmodule Fly do
  @otp_app :fly
  @moduledoc """
  Fly is an OTP application you can use to transform files on the fly with various workers.
  """
  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(LruCache, [:fly_cache, 1_000]),
    ]

    opts = [strategy: :one_for_one, name: Fly.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Run the worker specified by the `config_atom`, passing it the `input`, and
  merging the `options` into the configuration for the specified worker at
  runtime.
  """
  @spec run(atom(), binary(), map()) :: binary()
  def run(config_atom, input, options \\ %{})
          when is_atom(config_atom)
          and is_binary(input)
          and is_map(options) do
    case get_module_and_configuration(config_atom) do
      {mod, config} ->
        apply(mod, :call, [input, Map.merge(config, options)])
      _ ->
        Logger.error """
        No such Fly configuration: #{config_atom}.  Have you configured it?  It should
        look like:

            config :fly, :workers,
              %{
                #{config_atom}: {Fly.Worker.SomeModule, %{some: :config}}
              }

        You can look up the configuration options for the module you're trying to use in
        its documentation.
        """
    end
  end

  @doc """
  Run the worker, checking and filling the cache given a cache key.
  """
  @spec run_cached(binary(), atom(), binary(), map()) :: binary()
  def run_cached(cache_key, config_atom, input, options \\ %{}) do
    case LruCache.get(:fly_cache, cache_key) do
      nil ->
        result = run(config_atom, input, options)
        LruCache.put(:fly_cache, cache_key, result)
        result
      val -> val
    end
  end

  @spec get_module_and_configuration(atom()) :: {atom(), map()}
  defp get_module_and_configuration(config_atom) do
    @otp_app
      |> Application.get_env(:workers)
      |> Map.get(config_atom)
  end
end
