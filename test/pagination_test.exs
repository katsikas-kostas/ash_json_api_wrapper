defmodule AshJsonApiWrapper.PaginationTest do
  use ExUnit.Case, async: true

  defmodule PagedResource do
    use Ash.Resource,
      domain: AshJsonApiWrapper.PaginationTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/items"
      paginator {AshJsonApiWrapper.Paginator.OffsetLimit, page_size: 2, offset_param: "offset", limit_param: "limit"}
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule CustomPaginator do
    @behaviour AshJsonApiWrapper.Paginator

    def start(_opts) do
      {:ok, %{params: %{"cursor" => "start"}}}
    end

    def continue(_response, entities, _opts) do
      if length(entities) == 0 do
        :halt
      else
        {:ok, %{params: %{"cursor" => "next"}}}
      end
    end
  end

  defmodule ResourceWithCustomPaginator do
    use Ash.Resource,
      domain: AshJsonApiWrapper.PaginationTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/items"
      paginator {AshJsonApiWrapper.PaginationTest.CustomPaginator, []}
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule ResourceNoPagination do
    use Ash.Resource,
      domain: AshJsonApiWrapper.PaginationTest.Domain,
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
      resource PagedResource
      resource ResourceWithCustomPaginator
      resource ResourceNoPagination
    end
  end

  describe "OffsetLimit paginator" do
    test "first page sends ?offset=0&limit=page_size" do
      test_pid = self()

      Req.Test.stub(PagedResource, fn conn ->
        send(test_pid, {:query, conn.query_string})
        Req.Test.json(conn, [])
      end)

      Ash.read!(PagedResource)

      assert_received {:query, qs}
      assert qs =~ "offset=0"
      assert qs =~ "limit=2"
    end

    test "fetches multiple pages until API returns fewer items than page_size" do
      test_pid = self()
      page_responses = [
        [%{"id" => Ash.UUID.generate(), "name" => "A"}, %{"id" => Ash.UUID.generate(), "name" => "B"}],
        [%{"id" => Ash.UUID.generate(), "name" => "C"}]
      ]

      Req.Test.stub(PagedResource, fn conn ->
        send(test_pid, {:request, conn.query_string})
        response = Agent.get_and_update(:page_agent, fn [h | t] -> {h, t} end)
        Req.Test.json(conn, response)
      end)

      {:ok, _} = Agent.start_link(fn -> page_responses end, name: :page_agent)

      {:ok, results} = Ash.read(PagedResource)
      assert length(results) == 3
      assert Enum.map(results, & &1.name) == ["A", "B", "C"]

      # Verify two pages were fetched
      assert_received {:request, first_qs}
      assert first_qs =~ "offset=0"
      assert_received {:request, second_qs}
      assert second_qs =~ "offset=2"
    after
      Agent.stop(:page_agent)
    end

    test "respects Ash.Query.limit — stops fetching when limit reached" do
      test_pid = self()

      Req.Test.stub(PagedResource, fn conn ->
        send(test_pid, :page_requested)
        Req.Test.json(conn, [
          %{"id" => Ash.UUID.generate(), "name" => "A"},
          %{"id" => Ash.UUID.generate(), "name" => "B"}
        ])
      end)

      {:ok, results} = PagedResource |> Ash.Query.limit(1) |> Ash.read()
      assert length(results) == 1

      # Only one page fetched since limit is satisfied
      assert_received :page_requested
      refute_received :page_requested
    end
  end

  describe "custom paginator" do
    test "uses start/1 to get initial params" do
      test_pid = self()

      Req.Test.stub(ResourceWithCustomPaginator, fn conn ->
        send(test_pid, {:query, conn.query_string})
        Req.Test.json(conn, [])
      end)

      Ash.read!(ResourceWithCustomPaginator)

      assert_received {:query, qs}
      assert qs =~ "cursor=start"
    end
  end

  describe "no paginator" do
    test "makes a single request without pagination params" do
      Req.Test.stub(ResourceNoPagination, fn conn ->
        refute conn.query_string =~ "offset"
        refute conn.query_string =~ "limit"
        Req.Test.json(conn, [])
      end)

      Ash.read!(ResourceNoPagination)
    end
  end
end
