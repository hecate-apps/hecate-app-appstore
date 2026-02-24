%%% @doc API handler: GET /api/appstore/catalog
%%%
%%% Returns the full plugin catalog with license/install status
%%% for the current user. Only shows published plugins.
%%% @end
-module(browse_catalog_api).

-export([init/2, routes/0]).

-define(CATALOG_COLUMNS, [
    plugin_id, name, description, icon, github_repo, oci_image,
    selling_formula, seller_id, published_at, catalog_status,
    license_id, license_status
]).

-define(SQL, "SELECT "
    "c.plugin_id, c.name, c.description, c.icon, "
    "c.github_repo, c.oci_image, c.selling_formula, c.seller_id, "
    "c.published_at, c.status, "
    "l.license_id, l.status "
    "FROM plugin_catalog c "
    "LEFT JOIN licenses l ON c.plugin_id = l.plugin_id AND l.user_id = ?1 "
    "WHERE (c.status & 4) != 0 "
    "ORDER BY c.name").

routes() -> [{"/api/appstore/catalog", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> app_appstored_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case cowboy_req:header(<<"x-hecate-user-id">>, Req0) of
        undefined ->
            app_appstored_api_utils:json_error(401, <<"Missing X-Hecate-User-Id header">>, Req0);
        UserId ->
            case project_appstore_store:query(?SQL, [UserId]) of
                {ok, Rows} ->
                    Items = [row_to_map(R) || R <- Rows],
                    app_appstored_api_utils:json_ok(#{items => Items}, Req0);
                {error, Reason} ->
                    app_appstored_api_utils:json_error(500, Reason, Req0)
            end
    end.

row_to_map(Row) when is_tuple(Row) ->
    maps:from_list(lists:zip(?CATALOG_COLUMNS, tuple_to_list(Row))).
