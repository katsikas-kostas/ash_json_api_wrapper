defmodule AshJsonApiWrapper.FilterMappingTest do
  use ExUnit.Case, async: true
  require Ash.Query

  defmodule Post do
    use Ash.Resource,
      domain: AshJsonApiWrapper.FilterMappingTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/posts"
    end

    attributes do
      uuid_primary_key :id
      attribute :status, :string, public?: true
      attribute :author, :string, public?: true
      attribute :score, :integer, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule PostWithRuntimeFilter do
    use Ash.Resource,
      domain: AshJsonApiWrapper.FilterMappingTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/posts"

      field :score, runtime_filter: true
    end

    attributes do
      uuid_primary_key :id
      attribute :status, :string, public?: true
      attribute :score, :integer, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource Post
      resource PostWithRuntimeFilter
    end
  end

  describe "server-side equality filter" do
    test "equality filter sends field as query param" do
      Req.Test.stub(Post, fn conn ->
        assert conn.query_string =~ "status=active"
        Req.Test.json(conn, [])
      end)

      Post
      |> Ash.Query.filter(status == ^"active")
      |> Ash.read!()
    end

    test "multiple equality filters send multiple query params" do
      Req.Test.stub(Post, fn conn ->
        assert conn.query_string =~ "status=active"
        assert conn.query_string =~ "author=alice"
        Req.Test.json(conn, [])
      end)

      Post
      |> Ash.Query.filter(status == ^"active" and author == ^"alice")
      |> Ash.read!()
    end
  end

  describe "runtime filter" do
    test "runtime_filter field is not sent as query param and filtered in memory" do
      Req.Test.stub(PostWithRuntimeFilter, fn conn ->
        refute conn.query_string =~ "score"

        Req.Test.json(conn, [
          %{"id" => Ash.UUID.generate(), "status" => "active", "score" => 90},
          %{"id" => Ash.UUID.generate(), "status" => "active", "score" => 50}
        ])
      end)

      assert {:ok, results} =
               PostWithRuntimeFilter
               |> Ash.Query.filter(score == ^90)
               |> Ash.read()

      assert length(results) == 1
      assert hd(results).score == 90
    end
  end
end
