%%% @doc Plugin license aggregate state record.

-record(plugin_license_state, {
    license_id       :: binary() | undefined,
    user_id          :: binary() | undefined,
    plugin_id        :: binary() | undefined,
    status           :: non_neg_integer(),
    installed_version :: binary() | undefined,
    oci_image        :: binary() | undefined,
    granted_at       :: integer() | undefined,
    installed_at     :: integer() | undefined,
    upgraded_at      :: integer() | undefined,
    revoked_at       :: integer() | undefined,
    archived_at      :: integer() | undefined
}).
