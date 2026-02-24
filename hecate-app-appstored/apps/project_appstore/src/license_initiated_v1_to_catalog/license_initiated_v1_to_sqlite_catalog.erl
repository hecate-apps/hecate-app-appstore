%%% @doc Projection: license_initiated_v1 -> plugin_catalog table.
%%% Inserts a new row in the catalog when a seller initiates a license.
-module(license_initiated_v1_to_sqlite_catalog).
-export([project/1]).

-spec project(map()) -> ok | {error, term()}.
project(EventMap) ->
    LicenseId = app_appstored_api_utils:get_field(license_id, EventMap),
    PluginId = app_appstored_api_utils:get_field(plugin_id, EventMap),
    Name = app_appstored_api_utils:get_field(plugin_name, EventMap),
    Description = app_appstored_api_utils:get_field(description, EventMap),
    Icon = app_appstored_api_utils:get_field(icon, EventMap),
    GithubRepo = app_appstored_api_utils:get_field(github_repo, EventMap),
    OciImage = app_appstored_api_utils:get_field(oci_image, EventMap),
    SellingFormula = app_appstored_api_utils:get_field(selling_formula, EventMap),
    SellerId = app_appstored_api_utils:get_field(seller_id, EventMap),

    Sql = "INSERT OR REPLACE INTO plugin_catalog "
          "(plugin_id, license_id, name, description, icon, github_repo, "
          "oci_image, selling_formula, seller_id, status) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
    Params = [PluginId, LicenseId, Name, Description, Icon, GithubRepo,
              OciImage, SellingFormula, SellerId, 1],
    project_appstore_store:execute(Sql, Params).
