defmodule AshJsonApiWrapper.TestingHelpersTest do
  use ExUnit.Case, async: true

  defmodule Product do
    use Ash.Resource,
      domain: AshJsonApiWrapper.TestingHelpersTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/products"
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
      resource Product
    end
  end

  describe "stub_response/2" do
    test "stubs a list response" do
      id = Ash.UUID.generate()
      AshJsonApiWrapper.Testing.stub_response(Product, [%{"id" => id, "name" => "Widget"}])

      assert {:ok, [product]} = Ash.read(Product)
      assert product.id == id
      assert product.name == "Widget"
    end

    test "stubs an empty list" do
      AshJsonApiWrapper.Testing.stub_response(Product, [])

      assert {:ok, []} = Ash.read(Product)
    end
  end

  describe "stub_error/2" do
    test "stubs a 404 error" do
      AshJsonApiWrapper.Testing.stub_error(Product, 404)

      assert {:ok, []} = Ash.read(Product)
    end

    test "stubs a 500 error" do
      AshJsonApiWrapper.Testing.stub_error(Product, 500)

      assert {:error, %Ash.Error.Framework{}} = Ash.read(Product)
    end

    test "stubs a 403 error with custom message" do
      AshJsonApiWrapper.Testing.stub_error(Product, 403, "forbidden resource")

      assert {:error, %Ash.Error.Forbidden{errors: [error]}} = Ash.read(Product)
      assert Exception.message(error) =~ "forbidden resource"
    end
  end
end
