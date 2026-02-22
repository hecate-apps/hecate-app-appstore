%%% @doc Projection: plugin_installed_v1 -> licenses table (UPDATE installed).
-module(plugin_installed_v1_to_sqlite_licenses).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    LicenseId        = get(license_id, Event),
    InstalledVersion = get(version, Event),
    OciImage         = get(oci_image, Event),
    InstalledAt      = get(installed_at, Event),
    Sql = "UPDATE licenses SET installed = 1, installed_version = ?2, oci_image = ?3, installed_at = ?4 "
          "WHERE license_id = ?1",
    query_appstore_store:execute(Sql, [LicenseId, InstalledVersion, OciImage, InstalledAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
