%%% @doc SQLite store for appstore read models.
%%%
%%% Tables: plugin_catalog, licenses
%%% Catalog is populated by events (license_published_v1), not seeds.
%%% @end
-module(project_appstore_store).
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
            logger:error("[project_appstore_store] SQLite step error: ~p", [Code]),
            {error, Code};
        _ -> step_until_done(Stmt)
    end.

create_tables(Db) ->
    Stmts = [
        "CREATE TABLE IF NOT EXISTS plugin_catalog (
            plugin_id          TEXT PRIMARY KEY,
            license_id         TEXT,
            name               TEXT,
            org                TEXT,
            description        TEXT,
            icon               TEXT,
            github_repo        TEXT,
            oci_image          TEXT,
            selling_formula    TEXT,
            seller_id          TEXT,
            announced_at       INTEGER,
            published_at       INTEGER,
            status             INTEGER NOT NULL DEFAULT 0,
            status_label       TEXT DEFAULT ''
        );",
        "CREATE INDEX IF NOT EXISTS idx_catalog_seller ON plugin_catalog(seller_id);",
        "CREATE INDEX IF NOT EXISTS idx_catalog_license ON plugin_catalog(license_id);",

        "CREATE TABLE IF NOT EXISTS licenses (
            license_id         TEXT PRIMARY KEY,
            user_id            TEXT NOT NULL,
            plugin_id          TEXT NOT NULL,
            plugin_name        TEXT,
            oci_image          TEXT,
            granted_at         INTEGER NOT NULL,
            revoked_at         INTEGER,
            archived_at        INTEGER,
            status             INTEGER DEFAULT 0,
            status_label       TEXT DEFAULT '',
            UNIQUE(user_id, plugin_id)
        );",
        "CREATE INDEX IF NOT EXISTS idx_licenses_user ON licenses(user_id);",
        "CREATE INDEX IF NOT EXISTS idx_licenses_plugin ON licenses(plugin_id);"
    ],
    lists:foreach(fun(Sql) -> ok = esqlite3:exec(Db, Sql) end, Stmts),
    ok.
