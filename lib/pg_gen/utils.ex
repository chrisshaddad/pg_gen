defmodule PgGen.Utils do
  @moduledoc """
  Helper utilities shared between EctoGen and AbsintheGen.
  """

  alias PgGen.Builder

  @doc """
  If two field associations have the same name, prioritize the name with the default
  foreign key; use the non-default foreign key to name the other field

  iex> PgGen.Utils.deduplicate_associations([
  ...>   {:has_many, "comments", "Comment", []},
  ...>   {:has_many, "foos", "Foo", []},
  ...>   {:has_many, "comments", "Comment", fk: "alt_comment_id"}
  ...> ])
  [{:has_many, "alt_comments", "Comment", fk: "alt_comment_id"}, {:has_many, "comments", "Comment", []}, {:has_many, "foos", "Foo", []}]

  iex> PgGen.Utils.deduplicate_associations([
  ...>   {:many_to_many, "users", "User", [join_through: "objects", fk: "created_by"]},
  ...>   {:many_to_many, "users", "User", [join_through: "objects", fk: "archived_by"]}
  ...> ])
  [{:many_to_many, "archived_by_users", "User", join_through: "objects", fk: "archived_by"}, {:many_to_many, "created_by_users", "User", join_through: "objects", fk: "created_by"}]
  """
  def deduplicate_associations(attributes) do
    attributes =
      Enum.sort(attributes, fn l, r -> get_assoc_from_tuple(l) < get_assoc_from_tuple(r) end)

    associations = Enum.map(attributes, fn tuple -> get_assoc_from_tuple(tuple) end)

    duplicated_names = Enum.uniq(associations -- Enum.uniq(associations))

    Enum.map(attributes, fn tuple ->
      assoc = get_assoc_from_tuple(tuple)

      case Enum.member?(duplicated_names, assoc) do
        true ->
          case get_foreign_key_from_tuple(tuple) do
            nil ->
              tuple

            fk ->
              {relationship, table_name, queryable, opts} = tuple

              {relationship, Builder.format_assoc(fk, table_name) |> Inflex.pluralize(),
               queryable, opts}
          end

        false ->
          tuple
      end
    end)
  end

  @doc """
  iex> PgGen.Utils.deduplicate_join_associations([
  ...> {:many_to_many, "objects", "Object", join_through: "attachments"},
  ...> {:many_to_many, "objects", "Object", join_through: "object_activity_events"}
  ...> ], 1)
  [{:many_to_many, "objects_by_attachments", "Object", join_through: "attachments"},
  {:many_to_many, "objects_by_object_activity_events", "Object", join_through: "object_activity_events"}]

  """
  def deduplicate_join_associations(attributes, attempt) do
    associations = Enum.map(attributes, fn tuple -> get_assoc_from_tuple(tuple) end)

    duplicated_names = Enum.uniq(associations -- Enum.uniq(associations))

    Enum.map(attributes, fn tuple ->
      assoc = get_assoc_from_tuple(tuple)

      case Enum.member?(duplicated_names, assoc) do
        true ->
          case get_join_through_from_tuple(tuple) do
            nil ->
              tuple

            join_through ->
              {relationship, table_name, queryable, opts} = tuple

              case attempt do
                1 ->
                  {relationship,
                   Builder.format_assoc(table_name <> "_by", join_through)
                   |> Inflex.pluralize(), queryable, opts}

                2 ->
                  case Tuple.to_list(tuple) |> hd do
                    :has_many ->
                      tuple

                    _ ->
                      case opts[:join_keys] do
                        nil ->
                          tuple

                        [{prefix, _}, _] ->
                          {relationship, assoc <> "_by_" <> prefix, queryable, opts}
                      end
                  end
              end
          end

        false ->
          tuple
      end
    end)
  end

  def deduplicate_joins(associations), do: associations |> dedupe_first_pass |> dedupe_second_pass

  defp dedupe_first_pass(associations), do: deduplicate_join_associations(associations, 1)
  defp dedupe_second_pass(associations), do: deduplicate_join_associations(associations, 2)
  defp get_foreign_key_from_tuple({_, _, _, opts}), do: opts[:fk]
  defp get_join_through_from_tuple({_, _, _, opts}), do: opts[:join_through]

  defp get_assoc_from_tuple({_, assoc, _}), do: assoc
  defp get_assoc_from_tuple({_, assoc, _, _}), do: assoc
end
