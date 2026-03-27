defmodule AshJsonApiWrapper.AuthTest do
  use ExUnit.Case, async: true

  # --- Auth modules used in tests ---

  defmodule BearerAuth do
    @behaviour AshJsonApiWrapper.JsonApi.Auth
    def credentials(_resource), do: {:bearer, "my-secret-token"}
  end

  defmodule ApiKeyHeaderAuth do
    @behaviour AshJsonApiWrapper.JsonApi.Auth
    def credentials(_resource), do: {:api_key, "key-abc123", :header, "X-Api-Key"}
  end

  defmodule ApiKeyQueryAuth do
    @behaviour AshJsonApiWrapper.JsonApi.Auth
    def credentials(_resource), do: {:api_key, "key-abc123", :query, "api_key"}
  end

  defmodule BasicAuth do
    @behaviour AshJsonApiWrapper.JsonApi.Auth
    def credentials(_resource), do: {:basic, "admin", "s3cr3t"}
  end

  # --- Resources ---

  defmodule UserWithBearer do
    use Ash.Resource,
      domain: AshJsonApiWrapper.AuthTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/users"
      auth AshJsonApiWrapper.AuthTest.BearerAuth
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule UserWithApiKeyHeader do
    use Ash.Resource,
      domain: AshJsonApiWrapper.AuthTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/users"
      auth AshJsonApiWrapper.AuthTest.ApiKeyHeaderAuth
    end

    attributes do
      uuid_primary_key :id
    end

    actions do
      defaults [:read]
    end
  end

  defmodule UserWithApiKeyQuery do
    use Ash.Resource,
      domain: AshJsonApiWrapper.AuthTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/users"
      auth AshJsonApiWrapper.AuthTest.ApiKeyQueryAuth
    end

    attributes do
      uuid_primary_key :id
    end

    actions do
      defaults [:read]
    end
  end

  defmodule UserWithBasic do
    use Ash.Resource,
      domain: AshJsonApiWrapper.AuthTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/users"
      auth AshJsonApiWrapper.AuthTest.BasicAuth
    end

    attributes do
      uuid_primary_key :id
    end

    actions do
      defaults [:read]
    end
  end

  defmodule UserNoAuth do
    use Ash.Resource,
      domain: AshJsonApiWrapper.AuthTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/users"
    end

    attributes do
      uuid_primary_key :id
    end

    actions do
      defaults [:read]
    end
  end

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource UserWithBearer
      resource UserWithApiKeyHeader
      resource UserWithApiKeyQuery
      resource UserWithBasic
      resource UserNoAuth
    end
  end

  describe "bearer token auth" do
    test "injects Authorization: Bearer header" do
      Req.Test.stub(UserWithBearer, fn conn ->
        auth = Plug.Conn.get_req_header(conn, "authorization") |> List.first()
        assert auth == "Bearer my-secret-token"
        Req.Test.json(conn, [])
      end)

      Ash.read!(UserWithBearer)
    end
  end

  describe "API key via header" do
    test "injects custom header" do
      Req.Test.stub(UserWithApiKeyHeader, fn conn ->
        key = Plug.Conn.get_req_header(conn, "x-api-key") |> List.first()
        assert key == "key-abc123"
        Req.Test.json(conn, [])
      end)

      Ash.read!(UserWithApiKeyHeader)
    end
  end

  describe "API key via query param" do
    test "appends api_key to query string" do
      Req.Test.stub(UserWithApiKeyQuery, fn conn ->
        assert conn.query_string =~ "api_key=key-abc123"
        Req.Test.json(conn, [])
      end)

      Ash.read!(UserWithApiKeyQuery)
    end
  end

  describe "basic auth" do
    test "injects Authorization: Basic header with base64-encoded credentials" do
      Req.Test.stub(UserWithBasic, fn conn ->
        auth = Plug.Conn.get_req_header(conn, "authorization") |> List.first()
        expected = "Basic " <> Base.encode64("admin:s3cr3t")
        assert auth == expected
        Req.Test.json(conn, [])
      end)

      Ash.read!(UserWithBasic)
    end
  end

  describe "no auth configured" do
    test "makes unauthenticated request" do
      Req.Test.stub(UserNoAuth, fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == []
        Req.Test.json(conn, [])
      end)

      Ash.read!(UserNoAuth)
    end
  end
end
