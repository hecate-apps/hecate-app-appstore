%%% @doc Mesh publish proxy for Marketplace daemon.
%%%
%%% Marketplace runs as a separate BEAM node and does not have direct
%%% access to the Macula mesh client (which lives in hecate-daemon).
%%%
%%% This module routes mesh publish requests to hecate-daemon via
%%% OTP pg process groups. The hecate-daemon registers a handler in
%%% the pg group 'appstore_mesh_bridge' that forwards to
%%% hecate_mesh_client:publish/2.
%%%
%%% If hecate-daemon is not connected, publishes are silently dropped
%%% with a warning log.
%%% @end
-module(app_appstored_mesh_proxy).

-export([publish/2]).

-define(PG_SCOPE, hecate_app_appstored).
-define(PG_GROUP, appstore_mesh_bridge).

%% @doc Publish a message to the Macula mesh via hecate-daemon bridge.
%%
%% Returns ok if at least one bridge member received the message,
%% or {error, not_connected} if no bridge members exist.
-spec publish(Topic :: binary(), Payload :: map()) -> ok | {error, not_connected}.
publish(Topic, Payload) ->
    Members = get_bridge_members(),
    case Members of
        [] ->
            logger:warning("[app_appstored_mesh_proxy] No mesh bridge members, "
                          "dropping publish to ~s", [Topic]),
            {error, not_connected};
        _ ->
            Msg = {mesh_publish, Topic, Payload},
            lists:foreach(fun(Pid) -> Pid ! Msg end, Members),
            ok
    end.

%%% Internal

get_bridge_members() ->
    try pg:get_members(?PG_SCOPE, ?PG_GROUP) of
        Members -> Members
    catch
        error:_ -> []
    end.
