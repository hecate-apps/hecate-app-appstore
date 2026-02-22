%%% @doc Projection: plugin_removed_v1 -> licenses table (UPDATE uninstall).
-module(plugin_removed_v1_to_sqlite_licenses).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    LicenseId = get(license_id, Event),
    Sql = "UPDATE licenses SET installed = 0, installed_version = NULL, installed_at = NULL "
          "WHERE license_id = ?1",
    query_appstore_store:execute(Sql, [LicenseId]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
