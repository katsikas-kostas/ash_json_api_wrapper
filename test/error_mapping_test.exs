defmodule AshJsonApiWrapper.ErrorMappingTest do
  use ExUnit.Case, async: true

  defmodule Widget do
    use Ash.Resource,
      domain: AshJsonApiWrapper.ErrorMappingTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/widgets"
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]

      create :create do
        primary? true
        accept [:name]
      end
    end
  end

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource Widget
    end
  end

  describe "HTTP status → Ash error class" do
    test "400 → Ash.Error.Invalid" do
      stub_error(Widget, 400)
      assert {:error, %Ash.Error.Invalid{}} = Ash.read(Widget)
    end

    test "401 → Ash.Error.Forbidden" do
      stub_error(Widget, 401)
      assert {:error, %Ash.Error.Forbidden{}} = Ash.read(Widget)
    end

    test "403 → Ash.Error.Forbidden" do
      stub_error(Widget, 403)
      assert {:error, %Ash.Error.Forbidden{}} = Ash.read(Widget)
    end

    test "404 on list read returns empty" do
      stub_error(Widget, 404)
      assert {:ok, []} = Ash.read(Widget)
    end

    test "409 → Ash.Error.Invalid" do
      stub_error(Widget, 409)
      assert {:error, %Ash.Error.Invalid{}} = Ash.read(Widget)
    end

    test "422 → Ash.Error.Invalid" do
      stub_error(Widget, 422)
      assert {:error, %Ash.Error.Invalid{}} = Ash.read(Widget)
    end

    test "429 → Ash.Error.Framework" do
      stub_error(Widget, 429)
      assert {:error, %Ash.Error.Framework{}} = Ash.read(Widget)
    end

    test "500 → Ash.Error.Framework" do
      stub_error(Widget, 500)
      assert {:error, %Ash.Error.Framework{}} = Ash.read(Widget)
    end

    test "503 → Ash.Error.Framework" do
      stub_error(Widget, 503)
      assert {:error, %Ash.Error.Framework{}} = Ash.read(Widget)
    end
  end

  describe "error message extraction" do
    test "extracts message from JSON body 'error' key" do
      Req.Test.stub(Widget, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{"error" => "name is required"}))
      end)

      assert {:error, %Ash.Error.Invalid{errors: [error]}} = Ash.read(Widget)
      assert Exception.message(error) =~ "name is required"
    end

    test "extracts message from JSON body 'message' key" do
      Req.Test.stub(Widget, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(422, Jason.encode!(%{"message" => "validation failed"}))
      end)

      assert {:error, %Ash.Error.Invalid{errors: [error]}} = Ash.read(Widget)
      assert Exception.message(error) =~ "validation failed"
    end

    test "handles non-JSON error body gracefully" do
      Req.Test.stub(Widget, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/plain")
        |> Plug.Conn.send_resp(500, "Internal Server Error")
      end)

      assert {:error, %Ash.Error.Framework{}} = Ash.read(Widget)
    end
  end

  defp stub_error(resource, status) do
    Req.Test.stub(resource, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, Jason.encode!(%{"error" => "some error"}))
    end)
  end
end
