%%% @doc Projection: license_revoked_v1 -> licenses table (UPDATE revoked).
-module(license_revoked_v1_to_sqlite_licenses).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    LicenseId = get(license_id, Event),
    RevokedAt = get(revoked_at, Event),
    Sql = "UPDATE licenses SET revoked = 1, revoked_at = ?2 WHERE license_id = ?1",
    query_appstore_store:execute(Sql, [LicenseId, RevokedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
