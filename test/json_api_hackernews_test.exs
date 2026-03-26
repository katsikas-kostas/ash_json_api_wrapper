defmodule AshJsonApiWrapper.JsonApiHackernewsTest do
  use ExUnit.Case, async: true

  defmodule TopStory do
    @moduledoc false
    use Ash.Resource,
      domain: AshJsonApiWrapper.JsonApiHackernewsTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://hacker-news.firebaseio.com/v0"
      resource_path "/topstories"
    end

    attributes do
      integer_primary_key :id
    end

    actions do
      defaults [:read]
    end

    relationships do
      has_one :story, AshJsonApiWrapper.JsonApiHackernewsTest.Story do
        source_attribute :id
        destination_attribute :id
      end
    end
  end

  defmodule Story do
    @moduledoc false
    use Ash.Resource,
      domain: AshJsonApiWrapper.JsonApiHackernewsTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://hacker-news.firebaseio.com/v0"
      resource_path "/item"
    end

    attributes do
      integer_primary_key :id

      attribute :by, :string do
        allow_nil? false
      end

      attribute :score, :integer do
        allow_nil? false
      end

      attribute :title, :string
      attribute :url, :string
    end

    actions do
      defaults [:read]
    end

    relationships do
      has_one :user, AshJsonApiWrapper.JsonApiHackernewsTest.User do
        source_attribute :by
        destination_attribute :id
      end
    end
  end

  defmodule User do
    @moduledoc false
    use Ash.Resource,
      domain: AshJsonApiWrapper.JsonApiHackernewsTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://hacker-news.firebaseio.com/v0"
      resource_path "/user"
    end

    attributes do
      attribute :id, :string do
        primary_key? true
        allow_nil? false
      end
    end

    actions do
      defaults [:read]
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain

    resources do
      resource TopStory
      resource Story
      resource User
    end
  end

  test "hackernews-style flow works with json_api extension" do
    Req.Test.stub(TopStory, fn conn ->
      assert conn.request_path == "/v0/topstories"
      assert conn.method == "GET"
      Req.Test.json(conn, [%{"id" => 8863}])
    end)

    Req.Test.stub(Story, fn conn ->
      assert conn.request_path == "/v0/item"
      assert conn.method == "GET"

      Req.Test.json(conn, %{
        "id" => 8863,
        "by" => "pg",
        "score" => 42,
        "title" => "My YC app",
        "url" => "http://www.getflourish.com"
      })
    end)

    Req.Test.stub(User, fn conn ->
      assert conn.request_path == "/v0/user/pg"
      assert conn.method == "GET"
      Req.Test.json(conn, %{"id" => "pg"})
    end)

    assert {:ok, [top_story]} = Domain.read(TopStory)
    assert {:ok, story} = Ash.get(Story, top_story.id)
    assert {:ok, user} = Ash.get(User, story.by)

    assert is_binary(story.url)
    assert is_binary(story.title)
    assert is_binary(user.id)
    assert story.by == user.id
  end
end
