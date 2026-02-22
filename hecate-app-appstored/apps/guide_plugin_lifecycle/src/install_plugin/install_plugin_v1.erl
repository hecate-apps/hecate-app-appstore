%%% @doc install_plugin_v1 command
%%% Installs a plugin for a licensed user.
-module(install_plugin_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_license_id/1, get_plugin_id/1, get_plugin_name/1,
         get_version/1, get_oci_image/1]).

-record(install_plugin_v1, {
    license_id  :: binary(),
    plugin_id   :: binary(),
    plugin_name :: binary() | undefined,
    version     :: binary(),
    oci_image   :: binary() | undefined
}).

-export_type([install_plugin_v1/0]).
-opaque install_plugin_v1() :: #install_plugin_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, install_plugin_v1()} | {error, term()}.
new(#{license_id := LicenseId, plugin_id := PluginId, version := Version} = Params) ->
    {ok, #install_plugin_v1{
        license_id  = LicenseId,
        plugin_id   = PluginId,
        plugin_name = maps:get(plugin_name, Params, undefined),
        version     = Version,
        oci_image   = maps:get(oci_image, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(install_plugin_v1()) -> {ok, install_plugin_v1()} | {error, term()}.
validate(#install_plugin_v1{plugin_id = PluginId}) when
    not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, invalid_plugin_id};
validate(#install_plugin_v1{version = Version}) when
    not is_binary(Version); byte_size(Version) =:= 0 ->
    {error, invalid_version};
validate(#install_plugin_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(install_plugin_v1()) -> map().
to_map(#install_plugin_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"install_plugin">>,
        <<"license_id">>  => Cmd#install_plugin_v1.license_id,
        <<"plugin_id">>   => Cmd#install_plugin_v1.plugin_id,
        <<"plugin_name">> => Cmd#install_plugin_v1.plugin_name,
        <<"version">>     => Cmd#install_plugin_v1.version,
        <<"oci_image">>   => Cmd#install_plugin_v1.oci_image
    }.

-spec from_map(map()) -> {ok, install_plugin_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId  = get_value(license_id, Map),
    PluginId   = get_value(plugin_id, Map),
    PluginName = get_value(plugin_name, Map, undefined),
    Version    = get_value(version, Map),
    OciImage   = get_value(oci_image, Map, undefined),
    case {LicenseId, PluginId, Version} of
        {undefined, _, _} -> {error, missing_required_fields};
        {_, undefined, _} -> {error, missing_required_fields};
        {_, _, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #install_plugin_v1{
                license_id  = LicenseId,
                plugin_id   = PluginId,
                plugin_name = PluginName,
                version     = Version,
                oci_image   = OciImage
            }}
    end.

%% Accessors
-spec get_license_id(install_plugin_v1()) -> binary().
get_license_id(#install_plugin_v1{license_id = V}) -> V.

-spec get_plugin_id(install_plugin_v1()) -> binary().
get_plugin_id(#install_plugin_v1{plugin_id = V}) -> V.

-spec get_plugin_name(install_plugin_v1()) -> binary() | undefined.
get_plugin_name(#install_plugin_v1{plugin_name = V}) -> V.

-spec get_version(install_plugin_v1()) -> binary().
get_version(#install_plugin_v1{version = V}) -> V.

-spec get_oci_image(install_plugin_v1()) -> binary() | undefined.
get_oci_image(#install_plugin_v1{oci_image = V}) -> V.

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
