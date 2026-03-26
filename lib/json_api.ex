defmodule AshJsonApiWrapper.JsonApi do
  @moduledoc """
  A Spark DSL extension for wrapping external JSON APIs as Ash resources.

  Generates manual actions under the hood, aligned with Ash's recommended patterns.

  ## Example

      defmodule MyApp.User do
        use Ash.Resource,
          domain: MyApp.Domain,
          extensions: [AshJsonApiWrapper.JsonApi]

        json_api do
          base_url "https://api.example.com/v1"
          resource_path "/users"
          entity_path "data"           # extract from nested response
          case_convention :camel_case  # auto-convert camelCase → snake_case

          field :name, path: "profile.display_name"  # map nested field
        end

        attributes do
          uuid_primary_key :id
          attribute :name, :string, public?: true
        end

        actions do
          defaults [:read]
        end
      end
  """

  @field %Spark.Dsl.Entity{
    name: :field,
    target: AshJsonApiWrapper.JsonApi.FieldMapping,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The Ash attribute name."
      ],
      path: [
        type: :string,
        required: false,
        doc: "Dot-separated JSON path to the value (e.g., \"profile.display_name\")."
      ],
      runtime_filter: [
        type: :boolean,
        required: false,
        default: false,
        doc: "When true, filtering on this field is applied in-memory instead of as a query param."
      ]
    ],
    args: [:name]
  }

  @json_api %Spark.Dsl.Section{
    name: :json_api,
    describe: "Configure a JSON API-backed resource.",
    entities: [@field],
    schema: [
      base_url: [
        type: :string,
        required: true,
        doc: "The base URL of the external API (e.g., \"https://api.example.com/v1\")."
      ],
      resource_path: [
        type: :string,
        required: true,
        doc: "The resource path appended to the base URL (e.g., \"/users\")."
      ],
      entity_path: [
        type: :string,
        required: false,
        doc: "Dot-separated path to extract entities from the response body (e.g., \"data.items\")."
      ],
      case_convention: [
        type: {:in, [:camel_case]},
        required: false,
        doc: "Automatic key transformation. `:camel_case` converts camelCase keys to snake_case attributes."
      ],
      sort_param: [
        type: :string,
        required: false,
        default: "sort",
        doc: "The query parameter name used for sorting (default: \"sort\")."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@json_api],
    transformers: [AshJsonApiWrapper.JsonApi.Transformers.WireManualActions]
end
