%%% @doc Plugin license aggregate.
%%%
%%% Stream: license-{user_id}-{plugin_id}
%%% Store: appstore_store
%%%
%%% Lifecycle:
%%%   1. buy_license (birth event - license_bought_v1)
%%%   2. install_plugin / upgrade_plugin / remove_plugin
%%%   3. revoke_license
%%%   4. archive_license (walking skeleton)
%%% @end
-module(plugin_license_aggregate).

-behaviour(evoq_aggregate).

-include("plugin_license_status.hrl").
-include("plugin_license_state.hrl").

-export([init/1, execute/2, apply/2]).
-export([initial_state/0, apply_event/2]).
-export([flag_map/0]).

-type state() :: #plugin_license_state{}.
-export_type([state/0]).

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?PL_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #plugin_license_state{status = 0}.

%% --- Execute ---
%% NOTE: evoq calls execute(State, Payload) - State FIRST!

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate — only buy_license allowed
execute(#plugin_license_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"buy_license">> -> execute_buy_license(Payload);
        _ -> {error, license_not_acquired}
    end;

%% Archived — nothing allowed
execute(#plugin_license_state{status = S}, _Payload) when S band ?PL_ARCHIVED =/= 0 ->
    {error, license_archived};

%% Revoked — nothing allowed except archive
execute(#plugin_license_state{status = S}, Payload) when S band ?PL_REVOKED =/= 0 ->
    case get_command_type(Payload) of
        <<"archive_license">> -> execute_archive_license(Payload);
        _ -> {error, license_revoked}
    end;

%% Licensed — route by command type
execute(#plugin_license_state{status = S} = State, Payload) when S band ?PL_LICENSED =/= 0 ->
    case get_command_type(Payload) of
        <<"install_plugin">>  -> execute_install_plugin(Payload, State);
        <<"upgrade_plugin">>  -> execute_upgrade_plugin(Payload, State);
        <<"remove_plugin">>   -> execute_remove_plugin(Payload, State);
        <<"revoke_license">>  -> execute_revoke_license(Payload, State);
        <<"archive_license">> -> execute_archive_license(Payload);
        _ -> {error, unknown_command}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_buy_license(Payload) ->
    {ok, Cmd} = buy_license_v1:from_map(Payload),
    convert_events(maybe_buy_license:handle(Cmd), fun license_bought_v1:to_map/1).

execute_install_plugin(Payload, #plugin_license_state{status = S}) ->
    case S band ?PL_INSTALLED of
        0 ->
            {ok, Cmd} = install_plugin_v1:from_map(Payload),
            convert_events(maybe_install_plugin:handle(Cmd), fun plugin_installed_v1:to_map/1);
        _ ->
            {error, plugin_already_installed}
    end.

execute_upgrade_plugin(Payload, #plugin_license_state{status = S}) ->
    case S band ?PL_INSTALLED of
        0 -> {error, plugin_not_installed};
        _ ->
            {ok, Cmd} = upgrade_plugin_v1:from_map(Payload),
            convert_events(maybe_upgrade_plugin:handle(Cmd), fun plugin_upgraded_v1:to_map/1)
    end.

execute_remove_plugin(Payload, #plugin_license_state{status = S}) ->
    case S band ?PL_INSTALLED of
        0 -> {error, plugin_not_installed};
        _ ->
            {ok, Cmd} = remove_plugin_v1:from_map(Payload),
            convert_events(maybe_remove_plugin:handle(Cmd), fun plugin_removed_v1:to_map/1)
    end.

execute_revoke_license(Payload, _State) ->
    {ok, Cmd} = revoke_license_v1:from_map(Payload),
    convert_events(maybe_revoke_license:handle(Cmd), fun license_revoked_v1:to_map/1).

execute_archive_license(Payload) ->
    {ok, Cmd} = archive_license_v1:from_map(Payload),
    convert_events(maybe_archive_license:handle(Cmd), fun license_archived_v1:to_map/1).

%% --- Apply ---
%% NOTE: evoq calls apply(State, Event) - State FIRST!

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    apply_event(Event, State).

-spec apply_event(map(), state()) -> state().

apply_event(#{<<"event_type">> := <<"license_bought_v1">>} = E, S)   -> apply_bought(E, S);
apply_event(#{event_type := <<"license_bought_v1">>} = E, S)         -> apply_bought(E, S);
apply_event(#{<<"event_type">> := <<"plugin_installed_v1">>} = E, S)  -> apply_installed(E, S);
apply_event(#{event_type := <<"plugin_installed_v1">>} = E, S)       -> apply_installed(E, S);
apply_event(#{<<"event_type">> := <<"plugin_upgraded_v1">>} = E, S)  -> apply_upgraded(E, S);
apply_event(#{event_type := <<"plugin_upgraded_v1">>} = E, S)       -> apply_upgraded(E, S);
apply_event(#{<<"event_type">> := <<"plugin_removed_v1">>} = _E, S)  -> apply_removed(S);
apply_event(#{event_type := <<"plugin_removed_v1">>} = _E, S)       -> apply_removed(S);
apply_event(#{<<"event_type">> := <<"license_revoked_v1">>} = E, S)  -> apply_revoked(E, S);
apply_event(#{event_type := <<"license_revoked_v1">>} = E, S)       -> apply_revoked(E, S);
apply_event(#{<<"event_type">> := <<"license_archived_v1">>} = _E, S) -> apply_archived(S);
apply_event(#{event_type := <<"license_archived_v1">>} = _E, S)     -> apply_archived(S);
%% Unknown — ignore
apply_event(_E, S) -> S.

%% --- Apply helpers ---

apply_bought(E, State) ->
    State#plugin_license_state{
        license_id = get_value(license_id, E),
        user_id = get_value(user_id, E),
        plugin_id = get_value(plugin_id, E),
        status = evoq_bit_flags:set(0, ?PL_LICENSED),
        oci_image = get_value(oci_image, E),
        granted_at = get_value(granted_at, E)
    }.

apply_installed(E, #plugin_license_state{status = Status} = State) ->
    State#plugin_license_state{
        status = evoq_bit_flags:set(Status, ?PL_INSTALLED),
        installed_version = get_value(version, E),
        oci_image = get_value(oci_image, E),
        installed_at = get_value(installed_at, E)
    }.

apply_upgraded(E, #plugin_license_state{status = Status} = State) ->
    S0 = evoq_bit_flags:unset(Status, ?PL_OUTDATED),
    State#plugin_license_state{
        status = S0,
        installed_version = get_value(version, E),
        oci_image = get_value(oci_image, E),
        upgraded_at = get_value(upgraded_at, E)
    }.

apply_removed(#plugin_license_state{status = Status} = State) ->
    S0 = evoq_bit_flags:unset(Status, ?PL_INSTALLED),
    S1 = evoq_bit_flags:unset(S0, ?PL_OUTDATED),
    State#plugin_license_state{
        status = S1,
        installed_version = undefined,
        installed_at = undefined,
        upgraded_at = undefined
    }.

apply_revoked(E, #plugin_license_state{status = Status} = State) ->
    State#plugin_license_state{
        status = evoq_bit_flags:set(Status, ?PL_REVOKED),
        revoked_at = get_value(revoked_at, E)
    }.

apply_archived(#plugin_license_state{status = Status} = State) ->
    State#plugin_license_state{
        status = evoq_bit_flags:set(Status, ?PL_ARCHIVED)
    }.

%% --- Internal ---

get_command_type(#{<<"command_type">> := T}) -> T;
get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
