%%% @doc maybe_install_plugin handler
%%% Business logic for installing plugins.
%%% Validates the command and dispatches via evoq.
-module(maybe_install_plugin).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

%% @doc Handle install_plugin_v1 command (business logic only)
-spec handle(install_plugin_v1:install_plugin_v1()) ->
    {ok, [plugin_installed_v1:plugin_installed_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(install_plugin_v1:install_plugin_v1(), term()) ->
    {ok, [plugin_installed_v1:plugin_installed_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    PluginId = install_plugin_v1:get_plugin_id(Cmd),
    Version  = install_plugin_v1:get_version(Cmd),
    case validate_command(PluginId, Version) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(install_plugin_v1:install_plugin_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    LicenseId = install_plugin_v1:get_license_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = install_plugin,
        aggregate_type = plugin_license_aggregate,
        aggregate_id = LicenseId,
        payload = install_plugin_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => plugin_license_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => appstore_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).

%% Internal

validate_command(PluginId, Version) when
    is_binary(PluginId), byte_size(PluginId) > 0,
    is_binary(Version), byte_size(Version) > 0 ->
    ok;
validate_command(_, _) ->
    {error, invalid_command}.

create_event(Cmd) ->
    plugin_installed_v1:new(#{
        license_id  => install_plugin_v1:get_license_id(Cmd),
        plugin_id   => install_plugin_v1:get_plugin_id(Cmd),
        plugin_name => install_plugin_v1:get_plugin_name(Cmd),
        version     => install_plugin_v1:get_version(Cmd),
        oci_image   => install_plugin_v1:get_oci_image(Cmd)
    }).
