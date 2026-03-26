defmodule AshJsonApiWrapper.HooksTest do
  use ExUnit.Case, async: true

  defmodule HeaderHook do
    def inject_header(req_opts, header_name, header_value) do
      Keyword.update(req_opts, :headers, [{header_name, header_value}], fn existing ->
        [{header_name, header_value} | existing]
      end)
    end
  end

  defmodule BodyHook do
    # Adds a field to each item in a list response
    def add_field_to_items(body, key, value) when is_list(body) do
      Enum.map(body, &Map.put(&1, key, value))
    end

    def add_field_to_items(body, _key, _value), do: body
  end

  defmodule ResourceWithBeforeHook do
    use Ash.Resource,
      domain: AshJsonApiWrapper.HooksTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/items"
      before_request [{AshJsonApiWrapper.HooksTest.HeaderHook, :inject_header, ["x-tenant", "acme"]}]
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule ResourceWithAfterHook do
    use Ash.Resource,
      domain: AshJsonApiWrapper.HooksTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/items"
      after_response [{AshJsonApiWrapper.HooksTest.BodyHook, :add_field_to_items, ["source", "api"]}]
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
      attribute :source, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule ResourceWithMultipleHooks do
    use Ash.Resource,
      domain: AshJsonApiWrapper.HooksTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/items"
      before_request [
        {AshJsonApiWrapper.HooksTest.HeaderHook, :inject_header, ["x-first", "1"]},
        {AshJsonApiWrapper.HooksTest.HeaderHook, :inject_header, ["x-second", "2"]}
      ]
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
      resource ResourceWithBeforeHook
      resource ResourceWithAfterHook
      resource ResourceWithMultipleHooks
    end
  end

  describe "before_request hook" do
    test "MFA hook injects a request header" do
      Req.Test.stub(ResourceWithBeforeHook, fn conn ->
        tenant = Plug.Conn.get_req_header(conn, "x-tenant") |> List.first()
        assert tenant == "acme"
        Req.Test.json(conn, [])
      end)

      Ash.read!(ResourceWithBeforeHook)
    end
  end

  describe "after_response hook" do
    test "MFA hook transforms each item in the response body" do
      id = Ash.UUID.generate()

      Req.Test.stub(ResourceWithAfterHook, fn conn ->
        Req.Test.json(conn, [%{"id" => id, "name" => "Widget"}])
      end)

      assert {:ok, [item]} = Ash.read(ResourceWithAfterHook)
      assert item.name == "Widget"
      assert item.source == "api"
    end
  end

  describe "multiple before_request hooks" do
    test "all hooks execute in declared order" do
      Req.Test.stub(ResourceWithMultipleHooks, fn conn ->
        first = Plug.Conn.get_req_header(conn, "x-first") |> List.first()
        second = Plug.Conn.get_req_header(conn, "x-second") |> List.first()
        assert first == "1"
        assert second == "2"
        Req.Test.json(conn, [])
      end)

      Ash.read!(ResourceWithMultipleHooks)
    end
  end
end
