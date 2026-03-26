defmodule AshJsonApiWrapper.JsonApi.FieldMapping do
  @moduledoc false
  defstruct [:name, :path, runtime_filter: false]
end
