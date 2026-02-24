%%% @doc API handler: POST /api/appstore/licenses/initiate
%%%
%%% Initiates a new license for a seller.
%%% Lives in the initiate_license desk for vertical slicing.
%%% @end
-module(initiate_license_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/licenses/initiate", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> app_appstored_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case app_appstored_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_initiate_license(Params, Req1);
        {error, invalid_json, Req1} ->
            app_appstored_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_initiate_license(Params, Req) ->
    SellerId = app_appstored_api_utils:get_field(seller_id, Params),
    PluginId = app_appstored_api_utils:get_field(plugin_id, Params),

    case validate(SellerId, PluginId) of
        ok -> create_license(Params, Req);
        {error, Reason} -> app_appstored_api_utils:bad_request(Reason, Req)
    end.

validate(undefined, _) -> {error, <<"seller_id is required">>};
validate(SellerId, _) when not is_binary(SellerId); byte_size(SellerId) =:= 0 ->
    {error, <<"seller_id must be a non-empty string">>};
validate(_, undefined) -> {error, <<"plugin_id is required">>};
validate(_, PluginId) when not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, <<"plugin_id must be a non-empty string">>};
validate(_, _) -> ok.

create_license(Params, Req) ->
    CmdParams = #{
        seller_id => app_appstored_api_utils:get_field(seller_id, Params),
        plugin_id => app_appstored_api_utils:get_field(plugin_id, Params),
        plugin_name => app_appstored_api_utils:get_field(plugin_name, Params, undefined),
        description => app_appstored_api_utils:get_field(description, Params, undefined),
        icon => app_appstored_api_utils:get_field(icon, Params, undefined),
        github_repo => app_appstored_api_utils:get_field(github_repo, Params, undefined),
        oci_image => app_appstored_api_utils:get_field(oci_image, Params, undefined),
        selling_formula => app_appstored_api_utils:get_field(selling_formula, Params, undefined),
        org => app_appstored_api_utils:get_field(org, Params, undefined),
        version => app_appstored_api_utils:get_field(version, Params, undefined),
        manifest_tag => app_appstored_api_utils:get_field(manifest_tag, Params, undefined),
        tags => app_appstored_api_utils:get_field(tags, Params, undefined),
        homepage => app_appstored_api_utils:get_field(homepage, Params, undefined),
        min_daemon_version => app_appstored_api_utils:get_field(min_daemon_version, Params, undefined),
        publisher_identity => app_appstored_api_utils:get_field(publisher_identity, Params, undefined)
    },
    case initiate_license_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> app_appstored_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_initiate_license:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            app_appstored_api_utils:json_ok(201, #{
                license_id => initiate_license_v1:get_license_id(Cmd),
                seller_id => initiate_license_v1:get_seller_id(Cmd),
                plugin_id => initiate_license_v1:get_plugin_id(Cmd),
                plugin_name => initiate_license_v1:get_plugin_name(Cmd),
                description => initiate_license_v1:get_description(Cmd),
                icon => initiate_license_v1:get_icon(Cmd),
                github_repo => initiate_license_v1:get_github_repo(Cmd),
                oci_image => initiate_license_v1:get_oci_image(Cmd),
                selling_formula => initiate_license_v1:get_selling_formula(Cmd),
                org => initiate_license_v1:get_org(Cmd),
                plugin_version => initiate_license_v1:get_version(Cmd),
                manifest_tag => initiate_license_v1:get_manifest_tag(Cmd),
                tags => initiate_license_v1:get_tags(Cmd),
                homepage => initiate_license_v1:get_homepage(Cmd),
                min_daemon_version => initiate_license_v1:get_min_daemon_version(Cmd),
                publisher_identity => initiate_license_v1:get_publisher_identity(Cmd),
                version => Version,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            app_appstored_api_utils:bad_request(Reason, Req)
    end.
