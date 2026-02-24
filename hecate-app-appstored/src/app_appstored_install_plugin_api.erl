%%% @doc API handler: POST /api/appstore/plugins/install
%%%
%%% Marks a license as installed by updating the read model.
%%% This is an integration endpoint, not event-sourced.
%%% Called by hecate-node after a plugin is installed.
%%% @end
-module(app_appstored_install_plugin_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/plugins/install", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> app_appstored_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case app_appstored_api_utils:read_json_body(Req0) of
        {ok, Body, Req1} ->
            do_install(Body, Req1);
        {error, invalid_json, Req1} ->
            app_appstored_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_install(Body, Req) ->
    LicenseId = app_appstored_api_utils:get_field(license_id, Body),
    Version = app_appstored_api_utils:get_field(version, Body),
    case LicenseId of
        undefined ->
            app_appstored_api_utils:bad_request(<<"license_id is required">>, Req);
        _ ->
            Now = erlang:system_time(millisecond),
            Sql = "UPDATE licenses SET installed = 1, "
                  "installed_version = ?2, installed_at = ?3, upgraded_at = ?3 "
                  "WHERE license_id = ?1",
            case project_appstore_store:execute(Sql, [LicenseId, Version, Now]) of
                ok ->
                    app_appstored_api_utils:json_ok(#{
                        license_id => LicenseId,
                        installed => true,
                        installed_version => Version,
                        installed_at => Now
                    }, Req);
                {error, Reason} ->
                    app_appstored_api_utils:json_error(500, Reason, Req)
            end
    end.
