%%% @doc API handler: POST /api/appstore/plugins/install
%%%
%%% Installs a plugin for a licensed user.
%%% Lives in the install_plugin desk for vertical slicing.
%%% @end
-module(install_plugin_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/plugins/install", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> app_appstored_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case app_appstored_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_install(Params, Req1);
        {error, invalid_json, Req1} ->
            app_appstored_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_install(Params, Req) ->
    LicenseId  = app_appstored_api_utils:get_field(license_id, Params),
    PluginId   = app_appstored_api_utils:get_field(plugin_id, Params),
    PluginName = app_appstored_api_utils:get_field(plugin_name, Params),
    Version    = app_appstored_api_utils:get_field(version, Params),
    OciImage   = app_appstored_api_utils:get_field(oci_image, Params),

    case validate(LicenseId, PluginId, Version) of
        ok -> create_and_dispatch(LicenseId, PluginId, PluginName, Version, OciImage, Req);
        {error, Reason} -> app_appstored_api_utils:bad_request(Reason, Req)
    end.

validate(undefined, _, _) -> {error, <<"license_id is required">>};
validate(_, undefined, _) -> {error, <<"plugin_id is required">>};
validate(_, _, undefined) -> {error, <<"version is required">>};
validate(_, _, _) -> ok.

create_and_dispatch(LicenseId, PluginId, PluginName, Version, OciImage, Req) ->
    CmdParams = #{
        license_id  => LicenseId,
        plugin_id   => PluginId,
        plugin_name => PluginName,
        version     => Version,
        oci_image   => OciImage
    },
    case install_plugin_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> app_appstored_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_install_plugin:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            app_appstored_api_utils:json_ok(201, #{
                license_id  => install_plugin_v1:get_license_id(Cmd),
                plugin_id   => install_plugin_v1:get_plugin_id(Cmd),
                plugin_name => install_plugin_v1:get_plugin_name(Cmd),
                version     => Version,
                events      => EventMaps
            }, Req);
        {error, Reason} ->
            app_appstored_api_utils:bad_request(Reason, Req)
    end.
