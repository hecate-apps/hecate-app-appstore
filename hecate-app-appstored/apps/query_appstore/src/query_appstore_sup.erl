%%% @doc Top-level supervisor for query_appstore.
-module(query_appstore_sup).
-behaviour(supervisor).
-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        %% SQLite connection worker (must start first)
        #{
            id => query_appstore_store,
            start => {query_appstore_store, start_link, []},
            restart => permanent,
            type => worker
        },
        %% Projection: license_bought_v1 -> licenses table
        #{
            id => license_bought_v1_to_licenses_sup,
            start => {license_bought_v1_to_licenses_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: license_revoked_v1 -> licenses table
        #{
            id => license_revoked_v1_to_licenses_sup,
            start => {license_revoked_v1_to_licenses_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: plugin_installed_v1 -> licenses table
        #{
            id => plugin_installed_v1_to_licenses_sup,
            start => {plugin_installed_v1_to_licenses_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: plugin_upgraded_v1 -> licenses table
        #{
            id => plugin_upgraded_v1_to_licenses_sup,
            start => {plugin_upgraded_v1_to_licenses_sup, start_link, []},
            restart => permanent,
            type => supervisor
        },
        %% Projection: plugin_removed_v1 -> licenses table
        #{
            id => plugin_removed_v1_to_licenses_sup,
            start => {plugin_removed_v1_to_licenses_sup, start_link, []},
            restart => permanent,
            type => supervisor
        }
    ],
    {ok, {#{strategy => one_for_one, intensity => 10, period => 10}, Children}}.
