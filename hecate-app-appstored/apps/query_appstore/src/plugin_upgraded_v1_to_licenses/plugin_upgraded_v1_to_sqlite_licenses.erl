%%% @doc Projection: plugin_upgraded_v1 -> licenses table (UPDATE version).
-module(plugin_upgraded_v1_to_sqlite_licenses).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    LicenseId  = get(license_id, Event),
    Version    = get(version, Event),
    OciImage   = get(oci_image, Event),
    UpgradedAt = get(upgraded_at, Event),
    Sql = "UPDATE licenses SET installed_version = ?2, oci_image = ?3, upgraded_at = ?4 "
          "WHERE license_id = ?1",
    query_appstore_store:execute(Sql, [LicenseId, Version, OciImage, UpgradedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
