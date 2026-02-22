%%% @doc plugin_upgraded_v1 event
%%% Emitted when a plugin is successfully upgraded.
-module(plugin_upgraded_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_license_id/1, get_plugin_id/1, get_version/1,
         get_oci_image/1, get_upgraded_at/1]).

-record(plugin_upgraded_v1, {
    license_id  :: binary(),
    plugin_id   :: binary(),
    version     :: binary(),
    oci_image   :: binary() | undefined,
    upgraded_at :: integer()
}).

-export_type([plugin_upgraded_v1/0]).
-opaque plugin_upgraded_v1() :: #plugin_upgraded_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> plugin_upgraded_v1().
new(#{license_id := LicenseId, plugin_id := PluginId, version := Version} = Params) ->
    #plugin_upgraded_v1{
        license_id  = LicenseId,
        plugin_id   = PluginId,
        version     = Version,
        oci_image   = maps:get(oci_image, Params, undefined),
        upgraded_at = erlang:system_time(millisecond)
    }.

-spec to_map(plugin_upgraded_v1()) -> map().
to_map(#plugin_upgraded_v1{} = E) ->
    #{
        <<"event_type">>   => <<"plugin_upgraded_v1">>,
        <<"license_id">>   => E#plugin_upgraded_v1.license_id,
        <<"plugin_id">>    => E#plugin_upgraded_v1.plugin_id,
        <<"version">>      => E#plugin_upgraded_v1.version,
        <<"oci_image">>    => E#plugin_upgraded_v1.oci_image,
        <<"upgraded_at">>  => E#plugin_upgraded_v1.upgraded_at
    }.

-spec from_map(map()) -> {ok, plugin_upgraded_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = get_value(license_id, Map),
    PluginId  = get_value(plugin_id, Map),
    Version   = get_value(version, Map),
    case {LicenseId, PluginId, Version} of
        {undefined, _, _} -> {error, invalid_event};
        {_, undefined, _} -> {error, invalid_event};
        {_, _, undefined} -> {error, invalid_event};
        _ ->
            {ok, #plugin_upgraded_v1{
                license_id  = LicenseId,
                plugin_id   = PluginId,
                version     = Version,
                oci_image   = get_value(oci_image, Map, undefined),
                upgraded_at = get_value(upgraded_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_license_id(plugin_upgraded_v1()) -> binary().
get_license_id(#plugin_upgraded_v1{license_id = V}) -> V.

-spec get_plugin_id(plugin_upgraded_v1()) -> binary().
get_plugin_id(#plugin_upgraded_v1{plugin_id = V}) -> V.

-spec get_version(plugin_upgraded_v1()) -> binary().
get_version(#plugin_upgraded_v1{version = V}) -> V.

-spec get_oci_image(plugin_upgraded_v1()) -> binary() | undefined.
get_oci_image(#plugin_upgraded_v1{oci_image = V}) -> V.

-spec get_upgraded_at(plugin_upgraded_v1()) -> integer().
get_upgraded_at(#plugin_upgraded_v1{upgraded_at = V}) -> V.

%% Internal helper to get value with atom or binary key
get_value(Key, Map) ->
    get_value(Key, Map, undefined).

get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Map) of
                {ok, V} -> V;
                error -> Default
            end
    end.
