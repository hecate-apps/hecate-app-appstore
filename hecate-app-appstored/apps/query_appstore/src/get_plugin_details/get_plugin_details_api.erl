%%% @doc API handler: GET /api/appstore/plugin/:id
%%%
%%% Returns details for a single plugin, including license
%%% and install status for the current user.
%%% @end
-module(get_plugin_details_api).

-export([init/2, routes/0]).

-define(USER_ID, <<"rl">>).

-define(CATALOG_COLUMNS, [
    plugin_id, name, org, version, description, icon, oci_image,
    manifest_tag, tags, homepage, min_daemon_version, publisher_identity,
    published_at, cataloged_at, refreshed_at, status, retracted
]).

-define(LICENSE_COLUMNS, [
    license_id, user_id, plugin_id, plugin_name, installed,
    installed_version, oci_image, granted_at, installed_at,
    upgraded_at, revoked, revoked_at
]).

-define(CATALOG_SQL,
    "SELECT * FROM plugin_catalog WHERE plugin_id = ?1").

-define(LICENSE_SQL,
    "SELECT * FROM licenses WHERE plugin_id = ?1 AND user_id = ?2 AND revoked = 0").

routes() -> [{"/api/appstore/plugin/:id", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> app_appstored_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    PluginId = cowboy_req:binding(id, Req0),
    case query_appstore_store:query(?CATALOG_SQL, [PluginId]) of
        {ok, [Row]} ->
            Plugin = row_to_map(?CATALOG_COLUMNS, Row),
            License = fetch_license(PluginId),
            Result = Plugin#{license => License},
            app_appstored_api_utils:json_ok(#{plugin => Result}, Req0);
        {ok, []} ->
            app_appstored_api_utils:not_found(Req0);
        {error, Reason} ->
            app_appstored_api_utils:json_error(500, Reason, Req0)
    end.

fetch_license(PluginId) ->
    case query_appstore_store:query(?LICENSE_SQL, [PluginId, ?USER_ID]) of
        {ok, [Row]} -> row_to_map(?LICENSE_COLUMNS, Row);
        {ok, []} -> null;
        {error, _} -> null
    end.

row_to_map(Columns, Row) when is_list(Row) ->
    maps:from_list(lists:zip(Columns, Row)).
