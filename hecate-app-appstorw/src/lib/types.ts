// Types for AppstoreStudio custom element

export interface PluginApi {
	get: <T>(path: string) => Promise<T>;
	post: <T>(path: string, body: unknown) => Promise<T>;
	del: <T>(path: string) => Promise<T>;
}

export interface HealthData {
	status: string;
	version: string;
	node: string;
}

export interface CatalogItem {
	plugin_id: string;
	name: string;
	org: string;
	version: string;
	description: string | null;
	icon: string | null;
	oci_image: string;
	manifest_tag: string | null;
	tags: string | null;
	homepage: string | null;
	min_daemon_version: string | null;
	publisher_identity: string | null;
	published_at: number | null;
	cataloged_at: number;
	refreshed_at: number | null;
	status: number;
	retracted: number;
	// Joined from licenses table
	license_id: string | null;
	installed: number | null;
	installed_version: string | null;
}

export interface License {
	license_id: string;
	user_id: string;
	plugin_id: string;
	plugin_name: string | null;
	installed: number;
	installed_version: string | null;
	oci_image: string | null;
	granted_at: number;
	installed_at: number | null;
	upgraded_at: number | null;
	revoked: number;
	revoked_at: number | null;
}

export interface PluginDetail extends CatalogItem {
	license: License | null;
}

export type ActionState = 'get' | 'install' | 'installed' | 'update' | 'revoked' | 'loading';

export function getActionState(item: CatalogItem): ActionState {
	if (!item.license_id) return 'get';
	if (item.installed === 1) {
		// Check if outdated (catalog version > installed version)
		if (item.installed_version && item.version !== item.installed_version) return 'update';
		return 'installed';
	}
	return 'install';
}

export function parseTags(tagsJson: string | null): string[] {
	if (!tagsJson) return [];
	try {
		return JSON.parse(tagsJson);
	} catch {
		return [];
	}
}
