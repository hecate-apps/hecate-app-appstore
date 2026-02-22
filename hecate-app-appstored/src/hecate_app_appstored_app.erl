%%% @doc Hecate Marketplace daemon application.
%%%
%%% On startup:
%%% 1. Ensures the namespace directory layout exists
%%% 2. Starts ReckonDB infrastructure and appstore_store
%%% 3. Starts Cowboy on a Unix domain socket
%%% 4. Registers with hecate-daemon (when available)
%%% @end
-module(hecate_app_appstored_app).
-behaviour(application).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start/2, stop/1]).

%% reckon_db is excluded from dialyzer PLT (no debug_info in hex dep beams).
-dialyzer({nowarn_function, start_appstore_store/0}).

start(_StartType, _StartArgs) ->
    ok = app_appstored_paths:ensure_layout(),
    ok = ensure_pg_scope(),
    ok = start_appstore_store(),
    ok = start_cowboy(),
    logger:info("[hecate_app_appstored] Started, socket at ~s",
                [app_appstored_paths:socket_path("api.sock")]),
    hecate_app_appstored_sup:start_link().

stop(_State) ->
    ok = cowboy:stop_listener(app_appstored_http),
    cleanup_socket(),
    ok.

%%% Internal

ensure_pg_scope() ->
    case pg:start_link(hecate_app_appstored) of
        {ok, _Pid} -> ok;
        {error, {already_started, _Pid}} -> ok
    end.

start_appstore_store() ->
    DataDir = app_appstored_paths:reckon_path("marketplace"),
    ok = filelib:ensure_path(DataDir),
    Config = #store_config{
        store_id = appstore_store,
        data_dir = DataDir,
        mode = single,
        writer_pool_size = 5,
        reader_pool_size = 5,
        gateway_pool_size = 2,
        options = #{}
    },
    case reckon_db_sup:start_store(Config) of
        {ok, _Pid} ->
            logger:info("[hecate_app_appstored] appstore_store ready"),
            ok;
        {error, {already_started, _Pid}} ->
            logger:info("[hecate_app_appstored] appstore_store already running"),
            ok;
        {error, Reason} ->
            logger:error("[hecate_app_appstored] Failed to start appstore_store: ~p",
                        [Reason]),
            error({appstore_store_start_failed, Reason})
    end.

start_cowboy() ->
    SocketPath = app_appstored_paths:socket_path("api.sock"),
    cleanup_socket_file(SocketPath),
    StaticDir = static_dir(),
    CoreRoutes = [
        {"/health", app_appstored_health_api, []},
        {"/manifest", app_appstored_manifest_api, []},
        {"/ui/[...]", cowboy_static, {dir, StaticDir, [{mimetypes, cow_mimetypes, all}]}}
    ],
    ApiRoutes = app_appstored_api_routes:discover_routes(),
    Dispatch = cowboy_router:compile([{'_', CoreRoutes ++ ApiRoutes}]),
    TransOpts = #{
        socket_opts => [{ifaddr, {local, SocketPath}}],
        num_acceptors => 5
    },
    ProtoOpts = #{
        env => #{dispatch => Dispatch}
    },
    {ok, _} = cowboy:start_clear(app_appstored_http, TransOpts, ProtoOpts),
    ok.

static_dir() ->
    PrivDir = code:priv_dir(hecate_app_appstored),
    filename:join(PrivDir, "static").

cleanup_socket() ->
    SocketPath = app_appstored_paths:socket_path("api.sock"),
    cleanup_socket_file(SocketPath).

cleanup_socket_file(Path) ->
    case file:delete(Path) of
        ok -> ok;
        {error, enoent} -> ok;
        {error, Reason} ->
            logger:warning("[hecate_app_appstored] Failed to remove socket ~s: ~p",
                          [Path, Reason]),
            ok
    end.
