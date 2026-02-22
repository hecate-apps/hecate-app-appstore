%%% @doc API handler: GET /api/appstore/installed
%%%
%%% Returns all installed plugins for the current user,
%%% enriched with catalog info (name, org, description, icon).
%%% @end
-module(list_installed_api).

-export([init/2, routes/0]).

-define(USER_ID, <<"rl">>).

-define(INSTALLED_COLUMNS, [
    license_id, user_id, plugin_id, plugin_name, installed,
    installed_version, oci_image, granted_at, installed_at,
    upgraded_at, revoked, revoked_at,
    name, org, description, icon, catalog_version
]).

-define(SQL,
    "SELECT l.*, "
    "c.name, c.org, c.description, c.icon, c.version AS catalog_version "
    "FROM licenses l "
    "LEFT JOIN plugin_catalog c ON l.plugin_id = c.plugin_id "
    "WHERE l.user_id = ?1 AND l.installed = 1 AND l.revoked = 0").

routes() -> [{"/api/appstore/installed", ?MODULE, []}].

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
    maps:from_list(lists:zip(?INSTALLED_COLUMNS, Row)).
