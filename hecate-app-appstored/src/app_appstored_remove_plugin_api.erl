%%% @doc API handler: POST /api/appstore/plugins/remove
%%%
%%% Marks a license as uninstalled by updating the read model.
%%% This is an integration endpoint, not event-sourced.
%%% Called by hecate-node after a plugin is removed.
%%% @end
-module(app_appstored_remove_plugin_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/plugins/remove", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> app_appstored_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case app_appstored_api_utils:read_json_body(Req0) of
        {ok, Body, Req1} ->
            do_remove(Body, Req1);
        {error, invalid_json, Req1} ->
            app_appstored_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_remove(Body, Req) ->
    LicenseId = app_appstored_api_utils:get_field(license_id, Body),
    case LicenseId of
        undefined ->
            app_appstored_api_utils:bad_request(<<"license_id is required">>, Req);
        _ ->
            Sql = "UPDATE licenses SET installed = 0, "
                  "installed_version = NULL, installed_at = NULL, upgraded_at = NULL "
                  "WHERE license_id = ?1",
            case project_appstore_store:execute(Sql, [LicenseId]) of
                ok ->
                    app_appstored_api_utils:json_ok(#{
                        license_id => LicenseId,
                        installed => false
                    }, Req);
                {error, Reason} ->
                    app_appstored_api_utils:json_error(500, Reason, Req)
            end
    end.
