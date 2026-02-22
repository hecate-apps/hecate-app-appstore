%%% @doc Plugin license status bit flags.
%%%
%%% Status fields in aggregates are integers treated as bit flags.
%%% Each flag is a power of 2 (unique bit position).

-define(PL_LICENSED,    1).   %% User has acquired license (free or paid)
-define(PL_INSTALLED,   2).   %% Plugin is installed, .container exists
-define(PL_OUTDATED,    4).   %% Newer version available on mesh
-define(PL_REVOKED,     8).   %% License has been revoked
-define(PL_ARCHIVED,   16).   %% Walking skeleton

-define(PL_FLAG_MAP, #{
    1  => <<"Licensed">>,
    2  => <<"Installed">>,
    4  => <<"Outdated">>,
    8  => <<"Revoked">>,
    16 => <<"Archived">>
}).
