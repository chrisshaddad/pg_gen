defmodule EctoGen.FieldGenerator do
  @type_map %{
    "text" => "string",
    "citext" => "string",
    "timestamptz" => "utc_datetime",
    "uuid" => "Ecto.UUID",
    "jsonb" => "EctoJSON",
    "bool" => "boolean",
    "int4" => "integer"
  }

  @doc """
  ID fields are inferred; Ecto doesn't want them in the schema
  """
  def to_string({:field, "id", _type, _options}) do
    ""
  end

  def to_string({:field, name, type, options}) do
    case String.match?(type, ~r/(vector)$/) do
      true ->
        IO.puts("""
        Fix this to_string for field: #{name}: #{type}
        # See https://www.reddit.com/r/elixir/comments/72z762/how_to_use_postgrex_extension_to_create_an_ecto/
        #     https://hexdocs.pm/ecto/Ecto.Type.html
        """)

        ""

      false ->
        "field :#{name}, #{type}"
        |> process_options(options)
    end
  end

  def to_string({:belongs_to, name, queryable, options}) do
    "belongs_to :#{name}, #{queryable}"
    |> process_options(options)
  end

  def to_string({:has_many, name, queryable, options}) do
    "has_many :#{name}, #{queryable}"
    |> process_options(options)
  end

  def to_string({:many_to_many, name, queryable, options}) do
    "many_to_many :#{name}, #{queryable}"
    # we don't need foreign_key on many_to_many
    |> process_options(Keyword.drop(options, [:fk]))
  end

  def to_string({:has_one, name, queryable, options}) do
    "has_one :#{name}, #{queryable}"
    |> process_options(options)
  end

  defp process_options(base, options) do
    Enum.reduce(options, base, fn {k, v}, acc ->
      case k do
        :values ->
          "#{acc}, values: [#{Enum.map(v, &(":#{&1}")) |> Enum.join(", ")}]"
        :fk ->
          "#{acc}, foreign_key: :#{v}"

        :ref ->
          "#{acc}, references: :#{v}"

        :join_through ->
          "#{acc}, join_through: \"#{v}\""

        :join_keys ->
          [{current_id, _}, {associated_id, _}] = v
          "#{acc}, join_keys: [#{current_id}: :id, #{associated_id}: :id]"
      end
    end)
  end

  def type_map, do: @type_map
end
