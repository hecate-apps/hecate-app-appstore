%%% @doc maybe_upgrade_plugin handler
%%% Business logic for upgrading plugins.
%%% Validates the command and dispatches via evoq.
-module(maybe_upgrade_plugin).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, handle/2, dispatch/1]).

%% @doc Handle upgrade_plugin_v1 command (business logic only)
-spec handle(upgrade_plugin_v1:upgrade_plugin_v1()) ->
    {ok, [plugin_upgraded_v1:plugin_upgraded_v1()]} | {error, term()}.
handle(Cmd) ->
    handle(Cmd, undefined).

%% @doc Handle with state (for aggregate pattern)
-spec handle(upgrade_plugin_v1:upgrade_plugin_v1(), term()) ->
    {ok, [plugin_upgraded_v1:plugin_upgraded_v1()]} | {error, term()}.
handle(Cmd, _State) ->
    PluginId = upgrade_plugin_v1:get_plugin_id(Cmd),
    Version  = upgrade_plugin_v1:get_version(Cmd),
    case validate_command(PluginId, Version) of
        ok ->
            Event = create_event(Cmd),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Dispatch command via evoq (persists to ReckonDB)
-spec dispatch(upgrade_plugin_v1:upgrade_plugin_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    LicenseId = upgrade_plugin_v1:get_license_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = upgrade_plugin,
        aggregate_type = plugin_license_aggregate,
        aggregate_id = LicenseId,
        payload = upgrade_plugin_v1:to_map(Cmd),
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
    plugin_upgraded_v1:new(#{
        license_id => upgrade_plugin_v1:get_license_id(Cmd),
        plugin_id  => upgrade_plugin_v1:get_plugin_id(Cmd),
        version    => upgrade_plugin_v1:get_version(Cmd),
        oci_image  => upgrade_plugin_v1:get_oci_image(Cmd)
    }).
