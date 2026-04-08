defmodule AshJsonApiWrapper.CachingTest do
  use ExUnit.Case, async: false

  defmodule CachedResource do
    use Ash.Resource,
      domain: AshJsonApiWrapper.CachingTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/items"
      cache_ttl 60_000

      action :search, path: "/items/search"
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]

      read :search

      create :create do
        primary? true
        accept [:name]
      end

      update :update do
        primary? true
        accept [:name]
      end
    end
  end

  defmodule UncachedResource do
    use Ash.Resource,
      domain: AshJsonApiWrapper.CachingTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/items"
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource CachedResource
      resource UncachedResource
    end
  end

  setup_all do
    cache_name = AshJsonApiWrapper.JsonApi.Cache.cache_name(CachedResource)
    case Process.whereis(cache_name) do
      nil -> {:ok, _} = Cachex.start_link(cache_name)
      _ -> :ok
    end
    :ok
  end

  setup do
    Cachex.clear(AshJsonApiWrapper.JsonApi.Cache.cache_name(CachedResource))
    :ok
  end

  describe "cache hit" do
    test "second read returns cached result without HTTP request" do
      test_pid = self()
      id = Ash.UUID.generate()

      Req.Test.stub(CachedResource, fn conn ->
        send(test_pid, :http_called)
        Req.Test.json(conn, [%{"id" => id, "name" => "Widget"}])
      end)

      # First read — hits HTTP
      assert {:ok, [item]} = Ash.read(CachedResource)
      assert item.name == "Widget"
      assert_received :http_called

      # Second read — served from cache, no HTTP
      assert {:ok, [cached_item]} = Ash.read(CachedResource)
      assert cached_item.name == "Widget"
      refute_received :http_called
    end

    test "different queries have separate cache entries" do
      test_pid = self()

      Req.Test.stub(CachedResource, fn conn ->
        send(test_pid, :http_called)
        Req.Test.json(conn, [])
      end)

      Ash.read!(CachedResource)
      assert_received :http_called

      CachedResource
      |> Ash.Query.for_read(:search)
      |> Ash.read!()

      assert_received :http_called
    end
  end

  describe "cache invalidation on writes" do
    test "successful create invalidates the cache" do
      test_pid = self()
      id = Ash.UUID.generate()

      Req.Test.stub(CachedResource, fn conn ->
        case conn.method do
          "GET" ->
            send(test_pid, :read_called)
            Req.Test.json(conn, [%{"id" => id, "name" => "Widget"}])

          "POST" ->
            send(test_pid, :create_called)
            Req.Test.json(conn, %{"id" => Ash.UUID.generate(), "name" => "New"})
        end
      end)

      # Populate cache
      Ash.read!(CachedResource)
      assert_received :read_called

      # Second read — cached
      Ash.read!(CachedResource)
      refute_received :read_called

      # Create — should invalidate cache
      Ash.create!(CachedResource, %{name: "New"})
      assert_received :create_called

      # Third read — cache was invalidated, hits HTTP again
      Ash.read!(CachedResource)
      assert_received :read_called
    end

    test "successful update invalidates the cache" do
      test_pid = self()
      id = Ash.UUID.generate()

      Req.Test.stub(CachedResource, fn conn ->
        case conn.method do
          "GET" ->
            send(test_pid, :read_called)
            Req.Test.json(conn, [%{"id" => id, "name" => "Widget"}])

          "PATCH" ->
            send(test_pid, :update_called)
            Req.Test.json(conn, %{"id" => id, "name" => "Updated"})
        end
      end)

      # Populate cache
      {:ok, [item]} = Ash.read(CachedResource)
      assert_received :read_called

      # Cache hit
      Ash.read!(CachedResource)
      refute_received :read_called

      # Update invalidates cache
      Ash.update!(item, %{name: "Updated"})
      assert_received :update_called

      # Next read hits HTTP
      Ash.read!(CachedResource)
      assert_received :read_called
    end
  end

  describe "opt-out" do
    test "resource without cache_ttl makes no Cachex calls (no cache process needed)" do
      Req.Test.stub(UncachedResource, fn conn ->
        Req.Test.json(conn, [])
      end)

      # Works fine without a Cachex process started
      assert {:ok, []} = Ash.read(UncachedResource)
    end
  end
end
