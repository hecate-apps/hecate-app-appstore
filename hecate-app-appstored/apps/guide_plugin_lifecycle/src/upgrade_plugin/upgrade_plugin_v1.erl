%%% @doc upgrade_plugin_v1 command
%%% Upgrades an installed plugin to a new version.
-module(upgrade_plugin_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_license_id/1, get_plugin_id/1, get_version/1, get_oci_image/1]).

-record(upgrade_plugin_v1, {
    license_id :: binary(),
    plugin_id  :: binary(),
    version    :: binary(),
    oci_image  :: binary() | undefined
}).

-export_type([upgrade_plugin_v1/0]).
-opaque upgrade_plugin_v1() :: #upgrade_plugin_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, upgrade_plugin_v1()} | {error, term()}.
new(#{license_id := LicenseId, plugin_id := PluginId, version := Version} = Params) ->
    {ok, #upgrade_plugin_v1{
        license_id = LicenseId,
        plugin_id  = PluginId,
        version    = Version,
        oci_image  = maps:get(oci_image, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(upgrade_plugin_v1()) -> {ok, upgrade_plugin_v1()} | {error, term()}.
validate(#upgrade_plugin_v1{plugin_id = PluginId}) when
    not is_binary(PluginId); byte_size(PluginId) =:= 0 ->
    {error, invalid_plugin_id};
validate(#upgrade_plugin_v1{version = Version}) when
    not is_binary(Version); byte_size(Version) =:= 0 ->
    {error, invalid_version};
validate(#upgrade_plugin_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(upgrade_plugin_v1()) -> map().
to_map(#upgrade_plugin_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"upgrade_plugin">>,
        <<"license_id">>  => Cmd#upgrade_plugin_v1.license_id,
        <<"plugin_id">>   => Cmd#upgrade_plugin_v1.plugin_id,
        <<"version">>     => Cmd#upgrade_plugin_v1.version,
        <<"oci_image">>   => Cmd#upgrade_plugin_v1.oci_image
    }.

-spec from_map(map()) -> {ok, upgrade_plugin_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = get_value(license_id, Map),
    PluginId  = get_value(plugin_id, Map),
    Version   = get_value(version, Map),
    OciImage  = get_value(oci_image, Map, undefined),
    case {LicenseId, PluginId, Version} of
        {undefined, _, _} -> {error, missing_required_fields};
        {_, undefined, _} -> {error, missing_required_fields};
        {_, _, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #upgrade_plugin_v1{
                license_id = LicenseId,
                plugin_id  = PluginId,
                version    = Version,
                oci_image  = OciImage
            }}
    end.

%% Accessors
-spec get_license_id(upgrade_plugin_v1()) -> binary().
get_license_id(#upgrade_plugin_v1{license_id = V}) -> V.

-spec get_plugin_id(upgrade_plugin_v1()) -> binary().
get_plugin_id(#upgrade_plugin_v1{plugin_id = V}) -> V.

-spec get_version(upgrade_plugin_v1()) -> binary().
get_version(#upgrade_plugin_v1{version = V}) -> V.

-spec get_oci_image(upgrade_plugin_v1()) -> binary() | undefined.
get_oci_image(#upgrade_plugin_v1{oci_image = V}) -> V.

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
