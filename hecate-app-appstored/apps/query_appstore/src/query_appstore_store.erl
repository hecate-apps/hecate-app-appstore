%%% @doc SQLite store for query_appstore read models.
%%%
%%% Tables: plugin_catalog, licenses
%%% @end
-module(query_appstore_store).
-behaviour(gen_server).

-export([start_link/0, execute/1, execute/2, query/1, query/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {db :: esqlite3:esqlite3()}).

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    DbPath = app_appstored_paths:sqlite_path("query_appstore.db"),
    ok = filelib:ensure_dir(DbPath),
    {ok, Db} = esqlite3:open(DbPath),
    ok = esqlite3:exec(Db, "PRAGMA journal_mode=WAL;"),
    ok = esqlite3:exec(Db, "PRAGMA synchronous=NORMAL;"),
    ok = create_tables(Db),
    ok = seed_catalog(Db),
    {ok, #state{db = Db}}.

-spec execute(iodata()) -> ok | {error, term()}.
execute(Sql) ->
    gen_server:call(?MODULE, {execute, Sql, []}).

-spec execute(iodata(), [term()]) -> ok | {error, term()}.
execute(Sql, Params) ->
    gen_server:call(?MODULE, {execute, Sql, Params}).

-spec query(iodata()) -> {ok, [tuple()]} | {error, term()}.
query(Sql) ->
    gen_server:call(?MODULE, {query, Sql, []}).

-spec query(iodata(), [term()]) -> {ok, [tuple()]} | {error, term()}.
query(Sql, Params) ->
    gen_server:call(?MODULE, {query, Sql, Params}).

handle_call({execute, Sql, Params}, _From, #state{db = Db} = State) ->
    case Params of
        [] ->
            Result = esqlite3:exec(Db, Sql),
            {reply, Result, State};
        _ ->
            case esqlite3:prepare(Db, Sql) of
                {ok, Stmt} ->
                    ok = esqlite3:bind(Stmt, Params),
                    step_until_done(Stmt),
                    {reply, ok, State};
                {error, _} = Err ->
                    {reply, Err, State}
            end
    end;

handle_call({query, Sql, Params}, _From, #state{db = Db} = State) ->
    case esqlite3:prepare(Db, Sql) of
        {ok, Stmt} ->
            case Params of
                [] -> ok;
                _ -> ok = esqlite3:bind(Stmt, Params)
            end,
            Rows = esqlite3:fetchall(Stmt),
            {reply, {ok, Rows}, State};
        {error, _} = Err ->
            {reply, Err, State}
    end;

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{db = Db}) ->
    esqlite3:close(Db).

%% Internal

step_until_done(Stmt) ->
    case esqlite3:step(Stmt) of
        '$done' -> ok;
        {error, Code} ->
            logger:error("[query_appstore_store] SQLite step error: ~p", [Code]),
            {error, Code};
        _ -> step_until_done(Stmt)
    end.

create_tables(Db) ->
    Stmts = [
        "CREATE TABLE IF NOT EXISTS plugin_catalog (
            plugin_id          TEXT PRIMARY KEY,
            name               TEXT NOT NULL,
            org                TEXT NOT NULL,
            version            TEXT NOT NULL,
            description        TEXT,
            icon               TEXT,
            oci_image          TEXT NOT NULL,
            manifest_tag       TEXT,
            tags               TEXT,
            homepage           TEXT,
            min_daemon_version TEXT,
            publisher_identity TEXT,
            published_at       INTEGER,
            cataloged_at       INTEGER NOT NULL,
            refreshed_at       INTEGER,
            status             INTEGER NOT NULL DEFAULT 1,
            retracted          INTEGER DEFAULT 0
        );",
        "CREATE INDEX IF NOT EXISTS idx_catalog_org ON plugin_catalog(org);",
        "CREATE INDEX IF NOT EXISTS idx_catalog_name ON plugin_catalog(name);",

        "CREATE TABLE IF NOT EXISTS licenses (
            license_id         TEXT PRIMARY KEY,
            user_id            TEXT NOT NULL,
            plugin_id          TEXT NOT NULL,
            plugin_name        TEXT,
            installed          INTEGER DEFAULT 0,
            installed_version  TEXT,
            oci_image          TEXT,
            granted_at         INTEGER NOT NULL,
            installed_at       INTEGER,
            upgraded_at        INTEGER,
            revoked            INTEGER DEFAULT 0,
            revoked_at         INTEGER,
            UNIQUE(user_id, plugin_id)
        );",
        "CREATE INDEX IF NOT EXISTS idx_licenses_user ON licenses(user_id);",
        "CREATE INDEX IF NOT EXISTS idx_licenses_plugin ON licenses(plugin_id);"
    ],
    lists:foreach(fun(Sql) -> ok = esqlite3:exec(Db, Sql) end, Stmts),
    ok.

seed_catalog(Db) ->
    Now = erlang:system_time(millisecond),
    Seeds = [
        {<<"hecate-social/martha">>, <<"martha">>, <<"hecate-social">>,
         <<"0.1.0">>, <<"ALC/DevOps Agent">>,
         <<16#1F9D9/utf8>>,
         <<"ghcr.io/hecate-social/hecate-marthad:0.1.0">>,
         <<"martha-studio">>, <<"[\"devops\",\"alc\",\"agent\"]">>,
         null, null, null, Now, Now},
        {<<"hecate-social/trader">>, <<"trader">>, <<"hecate-social">>,
         <<"0.1.0">>, <<"AI Stock Trading Agents">>,
         <<16#1F4C8/utf8>>,
         <<"ghcr.io/hecate-social/hecate-traderd:0.1.0">>,
         <<"trader-studio">>, <<"[\"trading\",\"finance\"]">>,
         null, null, null, Now, Now}
    ],
    Sql = "INSERT OR IGNORE INTO plugin_catalog "
          "(plugin_id, name, org, version, description, icon, oci_image, "
          "manifest_tag, tags, homepage, min_daemon_version, publisher_identity, "
          "cataloged_at, refreshed_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14)",
    lists:foreach(fun(Row) ->
        case esqlite3:prepare(Db, Sql) of
            {ok, Stmt} ->
                ok = esqlite3:bind(Stmt, tuple_to_list(Row)),
                step_until_done(Stmt);
            {error, Reason} ->
                logger:warning("[query_appstore_store] Failed to seed: ~p", [Reason])
        end
    end, Seeds),
    logger:info("[query_appstore_store] Catalog seeded with ~p plugins", [length(Seeds)]),
    ok.
