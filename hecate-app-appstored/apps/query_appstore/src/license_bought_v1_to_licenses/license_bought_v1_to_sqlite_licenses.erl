%%% @doc Projection: license_bought_v1 -> licenses table (INSERT).
-module(license_bought_v1_to_sqlite_licenses).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    LicenseId  = get(license_id, Event),
    UserId     = get(user_id, Event),
    PluginId   = get(plugin_id, Event),
    PluginName = get(plugin_name, Event),
    OciImage   = get(oci_image, Event),
    GrantedAt  = get(granted_at, Event),
    Sql = "INSERT INTO licenses "
          "(license_id, user_id, plugin_id, plugin_name, oci_image, granted_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
    query_appstore_store:execute(Sql, [LicenseId, UserId, PluginId, PluginName, OciImage, GrantedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
