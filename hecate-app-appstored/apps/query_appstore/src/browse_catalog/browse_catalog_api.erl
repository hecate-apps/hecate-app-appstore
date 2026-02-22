%%% @doc API handler: GET /api/appstore/catalog
%%%
%%% Returns the full plugin catalog with license/install status
%%% for the current user. Excludes retracted plugins.
%%% @end
-module(browse_catalog_api).

-export([init/2, routes/0]).

-define(USER_ID, <<"rl">>).

-define(CATALOG_COLUMNS, [
    plugin_id, name, org, version, description, icon, oci_image,
    manifest_tag, tags, homepage, min_daemon_version, publisher_identity,
    published_at, cataloged_at, refreshed_at, status, retracted,
    license_id, installed, installed_version
]).

-define(SQL, "SELECT "
    "c.plugin_id, c.name, c.org, c.version, c.description, c.icon, "
    "c.oci_image, c.manifest_tag, c.tags, c.homepage, "
    "c.min_daemon_version, c.publisher_identity, "
    "c.published_at, c.cataloged_at, c.refreshed_at, c.status, c.retracted, "
    "l.license_id, l.installed, l.installed_version "
    "FROM plugin_catalog c "
    "LEFT JOIN licenses l ON c.plugin_id = l.plugin_id AND l.user_id = ?1 "
    "WHERE c.retracted = 0 "
    "ORDER BY c.name").

routes() -> [{"/api/appstore/catalog", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> app_appstored_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case query_appstore_store:query(?SQL, [?USER_ID]) of
        {ok, Rows} ->
            Items = [row_to_map(R) || R <- Rows],
            app_appstored_api_utils:json_ok(#{items => Items}, Req0);
        {error, Reason} ->
            app_appstored_api_utils:json_error(500, Reason, Req0)
    end.

row_to_map(Row) when is_list(Row) ->
    maps:from_list(lists:zip(?CATALOG_COLUMNS, Row)).
