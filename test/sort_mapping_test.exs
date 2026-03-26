defmodule AshJsonApiWrapper.SortMappingTest do
  use ExUnit.Case, async: true
  require Ash.Query

  defmodule Article do
    use Ash.Resource,
      domain: AshJsonApiWrapper.SortMappingTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/articles"
    end

    attributes do
      uuid_primary_key :id
      attribute :title, :string, public?: true
      attribute :published_at, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule ArticleCustomParam do
    use Ash.Resource,
      domain: AshJsonApiWrapper.SortMappingTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/articles"
      sort_param "order_by"
    end

    attributes do
      uuid_primary_key :id
      attribute :title, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource Article
      resource ArticleCustomParam
    end
  end

  describe "default sort param" do
    test "ascending sort sends ?sort=field" do
      Req.Test.stub(Article, fn conn ->
        assert conn.query_string =~ "sort=title"
        Req.Test.json(conn, [])
      end)

      Article
      |> Ash.Query.sort(:title)
      |> Ash.read!()
    end

    test "descending sort sends ?sort=-field" do
      Req.Test.stub(Article, fn conn ->
        assert conn.query_string =~ "sort=-title"
        Req.Test.json(conn, [])
      end)

      Article
      |> Ash.Query.sort(title: :desc)
      |> Ash.read!()
    end

    test "multi-field sort sends comma-separated values" do
      Req.Test.stub(Article, fn conn ->
        assert conn.query_string =~ "sort=title%2C-published_at" or
                 conn.query_string =~ "sort=title,-published_at"

        Req.Test.json(conn, [])
      end)

      Article
      |> Ash.Query.sort([:title, published_at: :desc])
      |> Ash.read!()
    end
  end

  describe "custom sort_param" do
    test "uses configured param name instead of 'sort'" do
      Req.Test.stub(ArticleCustomParam, fn conn ->
        assert conn.query_string =~ "order_by=title"
        refute conn.query_string =~ "sort="
        Req.Test.json(conn, [])
      end)

      ArticleCustomParam
      |> Ash.Query.sort(:title)
      |> Ash.read!()
    end
  end
end
