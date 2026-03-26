defmodule AshJsonApiWrapper.JsonApi do
  @moduledoc """
  A Spark DSL extension for wrapping external JSON APIs as Ash resources.

  Generates manual actions under the hood, aligned with Ash's recommended patterns.
  """

  @json_api %Spark.Dsl.Section{
    name: :json_api,
    describe: "Configure a JSON API-backed resource.",
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
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@json_api],
    transformers: [AshJsonApiWrapper.JsonApi.Transformers.WireManualActions]
end
