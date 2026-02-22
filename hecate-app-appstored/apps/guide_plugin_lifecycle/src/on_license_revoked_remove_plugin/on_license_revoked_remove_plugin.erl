%%% @doc Process Manager: On license revoked, remove the plugin if installed.
%%%
%%% Subscribes to license_revoked_v1 events from appstore_store.
%%% Checks whether the plugin is currently installed by looking for an
%%% existing .container file. If found, dispatches a remove_plugin_v1
%%% command to clean up the installation.
%%% @end
-module(on_license_revoked_remove_plugin).
-behaviour(gen_server).

-include_lib("reckon_gater/include/esdb_gater_types.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(EVENT_TYPE, <<"license_revoked_v1">>).
-define(SUB_NAME, <<"on_license_revoked_remove_plugin">>).
-define(STORE_ID, appstore_store).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, _} = reckon_evoq_adapter:subscribe(
        ?STORE_ID, event_type, ?EVENT_TYPE, ?SUB_NAME,
        #{subscriber_pid => self()}),
    {ok, #{}}.

handle_info({events, Events}, State) ->
    lists:foreach(fun(E) -> handle_event(E) end, Events),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

%% Internal

handle_event(Event) ->
    Map = app_appstored_projection_event:to_map(Event),
    PluginId = get_value(plugin_id, Map),
    UserId = get_value(user_id, Map),
    LicenseId = get_value(license_id, Map),
    Name = extract_plugin_name(PluginId),
    AppsDir = app_appstored_paths:gitops_apps_dir(),
    ContainerFile = filename:join(AppsDir, container_filename(Name)),
    case filelib:is_regular(ContainerFile) of
        true ->
            dispatch_remove_plugin(PluginId, UserId, LicenseId);
        false ->
            logger:info("[PM] Plugin ~s not installed (no container file), "
                        "skipping removal after license revocation", [PluginId])
    end.

%% @private Dispatch a remove_plugin_v1 command through the aggregate.
dispatch_remove_plugin(PluginId, UserId, LicenseId) ->
    Params = #{
        plugin_id => PluginId,
        user_id => UserId,
        license_id => LicenseId
    },
    case remove_plugin_v1:new(Params) of
        {ok, Cmd} ->
            case maybe_remove_plugin:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:info("[PM] Dispatched remove_plugin for ~s after license revocation",
                                [PluginId]);
                {error, Reason} ->
                    logger:error("[PM] Failed to remove plugin ~s after license revocation: ~p",
                                 [PluginId, Reason])
            end;
        {error, Reason} ->
            logger:error("[PM] Failed to create remove_plugin command for ~s: ~p",
                         [PluginId, Reason])
    end.

%% @private Extract the plugin name from a plugin_id like "hecate-social/trader".
extract_plugin_name(PluginId) ->
    case binary:split(PluginId, <<"/">>) of
        [_, Name] -> Name;
        [Name] -> Name
    end.

%% @private Build the .container filename for a plugin.
container_filename(Name) ->
    <<"hecate-", Name/binary, "d.container">>.

%% @private Get a value from a map, trying atom key first, then binary.
get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
