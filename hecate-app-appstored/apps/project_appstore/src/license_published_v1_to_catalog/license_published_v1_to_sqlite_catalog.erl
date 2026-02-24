%%% @doc Projection: license_published_v1 -> plugin_catalog table.
%%% Updates the catalog row to mark the plugin as published.
-module(license_published_v1_to_sqlite_catalog).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(EventMap) ->
    LicenseId = app_appstored_api_utils:get_field(license_id, EventMap),
    PublishedAt = app_appstored_api_utils:get_field(published_at, EventMap),

    Sql = "UPDATE plugin_catalog SET published_at = ?2, "
          "status = status | 4 WHERE license_id = ?1",
    project_appstore_store:execute(Sql, [LicenseId, PublishedAt]).
