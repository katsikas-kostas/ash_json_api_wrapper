defmodule AshJsonApiWrapper.JsonApi.Auth do
  @moduledoc """
  Behaviour for providing authentication credentials to `AshJsonApiWrapper.JsonApi` resources.

  Implement this behaviour to inject auth into every outgoing HTTP request.
  The callback is invoked before each request, enabling token refresh patterns.

  ## Example

      defmodule MyApp.ApiAuth do
        @behaviour AshJsonApiWrapper.JsonApi.Auth

        @impl true
        def credentials(_resource) do
          {:bearer, Application.fetch_env!(:my_app, :api_token)}
        end
      end

  Then reference it in your resource DSL:

      json_api do
        base_url "https://api.example.com/v1"
        resource_path "/users"
        auth MyApp.ApiAuth
      end

  ## Supported credential types

  - `{:bearer, token}` — `Authorization: Bearer <token>` header
  - `{:api_key, key, :header, header_name}` — custom header, e.g. `X-Api-Key`
  - `{:api_key, key, :query, param_name}` — appended as URL query param
  - `{:basic, username, password}` — `Authorization: Basic <base64(user:pass)>`
  - `:none` — no authentication
  """

  @type credentials ::
          {:bearer, token :: String.t()}
          | {:api_key, key :: String.t(), :header | :query, name :: String.t()}
          | {:basic, username :: String.t(), password :: String.t()}
          | :none

  @callback credentials(resource :: module()) :: credentials()
end
