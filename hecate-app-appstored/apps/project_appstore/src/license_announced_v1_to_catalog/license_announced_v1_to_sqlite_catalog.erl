%%% @doc Projection: license_announced_v1 -> plugin_catalog table.
%%% Updates the catalog row to mark the plugin as announced.
-module(license_announced_v1_to_sqlite_catalog).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(EventMap) ->
    LicenseId = app_appstored_api_utils:get_field(license_id, EventMap),
    AnnouncedAt = app_appstored_api_utils:get_field(announced_at, EventMap),

    Sql = "UPDATE plugin_catalog SET announced_at = ?2, "
          "status = status | 2 WHERE license_id = ?1",
    project_appstore_store:execute(Sql, [LicenseId, AnnouncedAt]).
