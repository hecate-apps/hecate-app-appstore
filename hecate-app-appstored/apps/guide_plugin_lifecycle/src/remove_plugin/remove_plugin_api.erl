%%% @doc API handler: POST /api/appstore/plugins/remove
%%%
%%% Removes an installed plugin.
%%% Lives in the remove_plugin desk for vertical slicing.
%%% @end
-module(remove_plugin_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/plugins/remove", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> app_appstored_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case app_appstored_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_remove(Params, Req1);
        {error, invalid_json, Req1} ->
            app_appstored_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_remove(Params, Req) ->
    LicenseId = app_appstored_api_utils:get_field(license_id, Params),
    PluginId  = app_appstored_api_utils:get_field(plugin_id, Params),

    case validate(LicenseId, PluginId) of
        ok -> create_and_dispatch(LicenseId, PluginId, Req);
        {error, Reason} -> app_appstored_api_utils:bad_request(Reason, Req)
    end.

validate(undefined, _) -> {error, <<"license_id is required">>};
validate(_, undefined) -> {error, <<"plugin_id is required">>};
validate(_, _) -> ok.

create_and_dispatch(LicenseId, PluginId, Req) ->
    CmdParams = #{
        license_id => LicenseId,
        plugin_id  => PluginId
    },
    case remove_plugin_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> app_appstored_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_remove_plugin:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            app_appstored_api_utils:json_ok(200, #{
                license_id => remove_plugin_v1:get_license_id(Cmd),
                plugin_id  => remove_plugin_v1:get_plugin_id(Cmd),
                version    => Version,
                events     => EventMaps
            }, Req);
        {error, Reason} ->
            app_appstored_api_utils:bad_request(Reason, Req)
    end.
