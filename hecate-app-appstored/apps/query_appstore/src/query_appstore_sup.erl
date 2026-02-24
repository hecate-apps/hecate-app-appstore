%%% @doc Top-level supervisor for query_appstore.
%%%
%%% Query handlers are stateless Cowboy handlers, not supervised processes.
%%% The SQLite store and projections live in project_appstore.
%%% @end
-module(query_appstore_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, []}}.
