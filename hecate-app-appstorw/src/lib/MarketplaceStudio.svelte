<svelte:options customElement={{ tag: "appstore-studio", shadow: "none" }} />

<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import type { PluginApi, HealthData, CatalogItem, PluginDetail, License } from './types.js';
	import { getActionState, parseTags } from './types.js';

	let { api }: { api: PluginApi } = $props();

	// --- Connection ---
	let health: HealthData | null = $state(null);
	let connectionStatus: 'connected' | 'connecting' | 'disconnected' = $state('connecting');
	let pollTimer: ReturnType<typeof setInterval> | undefined;

	// --- Data ---
	let catalog: CatalogItem[] = $state([]);
	let licenses: License[] = $state([]);
	let isLoading = $state(true);
	let error: string | null = $state(null);

	// --- UI state ---
	type Tab = 'browse' | 'my-plugins';
	let activeTab: Tab = $state('browse');
	let searchQuery = $state('');
	let selectedPlugin: PluginDetail | null = $state(null);
	let detailLoading = $state(false);
	let actionLoading: string | null = $state(null);

	// --- Filtered catalog ---
	let filteredCatalog = $derived.by(() => {
		let items = catalog;
		if (searchQuery.trim()) {
			const q = searchQuery.toLowerCase();
			items = items.filter(
				(p) =>
					p.name.toLowerCase().includes(q) ||
					p.org.toLowerCase().includes(q) ||
					(p.description && p.description.toLowerCase().includes(q)) ||
					parseTags(p.tags).some((t) => t.toLowerCase().includes(q))
			);
		}
		return items;
	});

	// --- Licensed plugins ---
	let licensedPlugins = $derived(
		catalog.filter((p) => p.license_id !== null && p.license_id !== undefined)
	);

	// --- Installed count ---
	let installedCount = $derived(
		catalog.filter((p) => p.installed === 1).length
	);

	// --- Fetch ---
	async function fetchHealth() {
		try {
			health = await api.get<HealthData>('/health');
			connectionStatus = 'connected';
		} catch {
			health = null;
			connectionStatus = 'disconnected';
		}
	}

	async function fetchCatalog() {
		try {
			const res = await api.get<{ items: CatalogItem[] }>('/api/appstore/catalog');
			catalog = res.items;
		} catch (e) {
			error = e instanceof Error ? e.message : String(e);
		}
	}

	async function fetchAll() {
		isLoading = true;
		error = null;
		await fetchCatalog();
		isLoading = false;
	}

	async function openDetail(pluginId: string) {
		detailLoading = true;
		try {
			selectedPlugin = await api.get<PluginDetail>(`/api/appstore/plugin/${encodeURIComponent(pluginId)}`);
		} catch (e) {
			console.error('[marketplace] Failed to load plugin detail:', e);
		} finally {
			detailLoading = false;
		}
	}

	function closeDetail() {
		selectedPlugin = null;
	}

	// --- Actions ---
	async function buyLicense(item: CatalogItem) {
		actionLoading = item.plugin_id;
		try {
			await api.post('/api/appstore/licenses/buy', {
				user_id: 'rl',
				plugin_id: item.plugin_id,
				plugin_name: item.name,
				oci_image: item.oci_image
			});
			await fetchCatalog();
			if (selectedPlugin && selectedPlugin.plugin_id === item.plugin_id) {
				await openDetail(item.plugin_id);
			}
		} catch (e) {
			console.error('[marketplace] Buy license failed:', e);
		} finally {
			actionLoading = null;
		}
	}

	async function installPlugin(item: CatalogItem) {
		actionLoading = item.plugin_id;
		try {
			await api.post('/api/appstore/plugins/install', {
				license_id: item.license_id,
				plugin_id: item.plugin_id,
				plugin_name: item.name,
				version: item.version,
				oci_image: item.oci_image
			});
			await fetchCatalog();
			if (selectedPlugin && selectedPlugin.plugin_id === item.plugin_id) {
				await openDetail(item.plugin_id);
			}
		} catch (e) {
			console.error('[marketplace] Install failed:', e);
		} finally {
			actionLoading = null;
		}
	}

	async function removePlugin(item: CatalogItem) {
		actionLoading = item.plugin_id;
		try {
			await api.post('/api/appstore/plugins/remove', {
				license_id: item.license_id,
				plugin_id: item.plugin_id
			});
			await fetchCatalog();
			if (selectedPlugin && selectedPlugin.plugin_id === item.plugin_id) {
				await openDetail(item.plugin_id);
			}
		} catch (e) {
			console.error('[marketplace] Remove failed:', e);
		} finally {
			actionLoading = null;
		}
	}

	function handleAction(item: CatalogItem) {
		const state = getActionState(item);
		switch (state) {
			case 'get':
				buyLicense(item);
				break;
			case 'install':
				installPlugin(item);
				break;
			case 'installed':
				removePlugin(item);
				break;
			case 'update':
				installPlugin(item);
				break;
		}
	}

	onMount(() => {
		fetchHealth();
		pollTimer = setInterval(fetchHealth, 5000);
		fetchAll();
	});

	onDestroy(() => {
		if (pollTimer) clearInterval(pollTimer);
	});
</script>

<div class="flex flex-col h-full overflow-hidden">
	<!-- Header -->
	<div class="border-b border-surface-600 bg-surface-800/50 px-4 py-3 shrink-0">
		<div class="flex items-center gap-3">
			<span class="text-xl">{'\u{1F3EA}'}</span>
			<h1 class="text-sm font-semibold text-surface-100">Marketplace</h1>

			<!-- Connection status -->
			<div class="flex items-center gap-1.5 text-[10px]">
				<span
					class="inline-block w-1.5 h-1.5 rounded-full {connectionStatus === 'connected'
						? 'bg-success-400'
						: connectionStatus === 'connecting'
							? 'bg-yellow-400 animate-pulse'
							: 'bg-danger-400'}"
				></span>
				<span class="text-surface-500">
					{connectionStatus === 'connected'
						? `v${health?.version ?? '?'}`
						: connectionStatus}
				</span>
			</div>

			<div class="flex-1"></div>

			<!-- Search -->
			<input
				bind:value={searchQuery}
				placeholder="Search plugins..."
				class="w-56 bg-surface-700 border border-surface-600 rounded-lg
					px-3 py-1.5 text-xs text-surface-100 placeholder-surface-500
					focus:outline-none focus:border-accent-500"
			/>
		</div>

		<!-- Tabs -->
		<div class="flex gap-1 mt-3">
			<button
				onclick={() => (activeTab = 'browse')}
				class="px-3 py-1.5 rounded-lg text-xs font-medium transition-colors
					{activeTab === 'browse'
					? 'bg-accent-600 text-surface-50'
					: 'text-surface-400 hover:text-surface-200 hover:bg-surface-700'}"
			>
				Browse
			</button>
			<button
				onclick={() => (activeTab = 'my-plugins')}
				class="px-3 py-1.5 rounded-lg text-xs font-medium transition-colors
					{activeTab === 'my-plugins'
					? 'bg-accent-600 text-surface-50'
					: 'text-surface-400 hover:text-surface-200 hover:bg-surface-700'}"
			>
				My Plugins
				{#if installedCount > 0}
					<span class="ml-1 px-1.5 py-0.5 rounded-full text-[10px] bg-success-500/20 text-success-400">
						{installedCount}
					</span>
				{/if}
			</button>
		</div>
	</div>

	<!-- Content -->
	<div class="flex flex-1 overflow-hidden relative">
		<!-- Main grid area -->
		<div class="flex-1 overflow-y-auto p-4">
			{#if isLoading}
				<div class="flex items-center justify-center h-full">
					<div class="text-center text-surface-400">
						<div class="text-2xl mb-2 animate-pulse">{'\u{1F3EA}'}</div>
						<div class="text-sm">Loading marketplace...</div>
					</div>
				</div>
			{:else if error}
				<div class="flex items-center justify-center h-full">
					<div class="text-center">
						<div class="text-2xl mb-2">{'\u{26A0}'}</div>
						<div class="text-sm text-danger-400">{error}</div>
						<button
							onclick={fetchAll}
							class="mt-4 px-4 py-2 rounded-lg text-xs bg-accent-600 text-surface-50 hover:bg-accent-500"
						>
							Retry
						</button>
					</div>
				</div>
			{:else if activeTab === 'browse'}
				<!-- Browse tab -->
				{#if filteredCatalog.length === 0}
					<div class="flex flex-col items-center justify-center py-20 text-center">
						{#if searchQuery.trim()}
							<div class="text-2xl mb-3 text-surface-500">{'\u{1F50D}'}</div>
							<p class="text-sm text-surface-400">No plugins matching "{searchQuery}"</p>
						{:else}
							<div class="text-2xl mb-3 text-surface-500">{'\u{1F4E6}'}</div>
							<p class="text-sm text-surface-400">No plugins available yet</p>
						{/if}
					</div>
				{:else}
					<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
						{#each filteredCatalog as item (item.plugin_id)}
							{@const action = getActionState(item)}
							{@const loading = actionLoading === item.plugin_id}
							<div
								class="group rounded-xl border border-surface-600 bg-surface-800/80
									hover:border-accent-500/50 hover:bg-surface-800 transition-all"
							>
								<!-- Card header (clickable for details) -->
								<button
									onclick={() => openDetail(item.plugin_id)}
									class="w-full text-left p-4 pb-2"
								>
									<div class="flex items-start gap-3">
										<span class="text-2xl shrink-0">{item.icon ?? '\u{1F4E6}'}</span>
										<div class="flex-1 min-w-0">
											<div class="flex items-center gap-2">
												<span class="font-medium text-sm text-surface-100 truncate">
													{item.name}
												</span>
												<span class="text-[10px] px-1.5 py-0.5 rounded-full bg-surface-700 text-surface-400 border border-surface-600 shrink-0">
													v{item.version}
												</span>
											</div>
											<div class="text-[11px] text-surface-500 mt-0.5">{item.org}</div>
											{#if item.description}
												<div class="text-xs text-surface-400 mt-2 line-clamp-2">
													{item.description}
												</div>
											{/if}
										</div>
									</div>
								</button>

								<!-- Card footer with tags + action -->
								<div class="px-4 pb-3 pt-1 flex items-center justify-between gap-2">
									<div class="flex gap-1 flex-wrap min-w-0">
										{#each parseTags(item.tags).slice(0, 3) as tag}
											<span class="text-[10px] px-1.5 py-0.5 rounded bg-surface-700/50 text-surface-500">
												{tag}
											</span>
										{/each}
									</div>

									<button
										onclick={(e) => { e.stopPropagation(); handleAction(item); }}
										disabled={loading || action === 'revoked'}
										class="shrink-0 px-3 py-1.5 rounded-lg text-xs font-medium transition-colors
											{loading
											? 'bg-surface-600 text-surface-400 cursor-wait'
											: action === 'get'
												? 'bg-accent-600 text-surface-50 hover:bg-accent-500'
												: action === 'install'
													? 'bg-success-500 text-surface-50 hover:bg-success-400'
													: action === 'installed'
														? 'bg-surface-700 text-surface-300 hover:bg-danger-500/20 hover:text-danger-400 border border-surface-600'
														: action === 'update'
															? 'bg-accent-600 text-surface-50 hover:bg-accent-500'
															: 'bg-surface-700 text-surface-500 cursor-not-allowed'}"
									>
										{#if loading}
											...
										{:else if action === 'get'}
											Get
										{:else if action === 'install'}
											Install
										{:else if action === 'installed'}
											<span class="group-hover:hidden">Installed</span>
											<span class="hidden group-hover:inline">Remove</span>
										{:else if action === 'update'}
											Update
										{:else}
											Revoked
										{/if}
									</button>
								</div>
							</div>
						{/each}
					</div>
				{/if}
			{:else if activeTab === 'my-plugins'}
				<!-- My Plugins tab -->
				{#if licensedPlugins.length === 0}
					<div class="flex flex-col items-center justify-center py-20 text-center">
						<div class="text-2xl mb-3 text-surface-500">{'\u{1F4E6}'}</div>
						<h3 class="text-sm font-medium text-surface-200 mb-1">No plugins yet</h3>
						<p class="text-xs text-surface-400">
							Browse the catalog and get plugins to see them here
						</p>
						<button
							onclick={() => (activeTab = 'browse')}
							class="mt-4 px-4 py-2 rounded-lg text-xs bg-accent-600 text-surface-50 hover:bg-accent-500"
						>
							Browse Catalog
						</button>
					</div>
				{:else}
					<div class="space-y-2">
						{#each licensedPlugins as item (item.plugin_id)}
							{@const action = getActionState(item)}
							{@const loading = actionLoading === item.plugin_id}
							<div
								class="flex items-center gap-4 p-3 rounded-xl border border-surface-600
									bg-surface-800/80 hover:border-surface-500 transition-all"
							>
								<span class="text-xl shrink-0">{item.icon ?? '\u{1F4E6}'}</span>
								<div class="flex-1 min-w-0">
									<button
										onclick={() => openDetail(item.plugin_id)}
										class="text-left"
									>
										<div class="flex items-center gap-2">
											<span class="font-medium text-sm text-surface-100">{item.name}</span>
											<span class="text-[10px] px-1.5 py-0.5 rounded-full bg-surface-700 text-surface-400 border border-surface-600">
												v{item.installed_version ?? item.version}
											</span>
											{#if item.installed === 1}
												<span class="text-[10px] px-1.5 py-0.5 rounded-full bg-success-500/20 text-success-400">
													Running
												</span>
											{/if}
										</div>
										{#if item.description}
											<div class="text-xs text-surface-400 mt-0.5 truncate">{item.description}</div>
										{/if}
									</button>
								</div>
								<button
									onclick={() => handleAction(item)}
									disabled={loading || action === 'revoked'}
									class="shrink-0 px-3 py-1.5 rounded-lg text-xs font-medium transition-colors
										{loading
										? 'bg-surface-600 text-surface-400 cursor-wait'
										: action === 'install'
											? 'bg-success-500 text-surface-50 hover:bg-success-400'
											: action === 'installed'
												? 'bg-surface-700 text-surface-300 hover:bg-danger-500/20 hover:text-danger-400 border border-surface-600'
												: action === 'update'
													? 'bg-accent-600 text-surface-50 hover:bg-accent-500'
													: 'bg-surface-700 text-surface-500 cursor-not-allowed'}"
								>
									{#if loading}
										...
									{:else if action === 'install'}
										Install
									{:else if action === 'installed'}
										Remove
									{:else if action === 'update'}
										Update
									{:else}
										Revoked
									{/if}
								</button>
							</div>
						{/each}
					</div>
				{/if}
			{/if}
		</div>

		<!-- Detail panel (slide-over) -->
		{#if selectedPlugin || detailLoading}
			<!-- Backdrop -->
			<button
				onclick={closeDetail}
				class="absolute inset-0 bg-surface-950/50 z-10"
				aria-label="Close detail"
			></button>

			<!-- Panel -->
			<div class="absolute top-0 right-0 bottom-0 w-[400px] max-w-[90vw] z-20
				bg-surface-800 border-l border-surface-600 overflow-y-auto shadow-2xl">
				{#if detailLoading}
					<div class="flex items-center justify-center h-full">
						<div class="text-surface-400 animate-pulse">Loading...</div>
					</div>
				{:else if selectedPlugin}
					{@const detail = selectedPlugin}
					{@const detailAction = detail.license
						? (detail.license.installed === 1
							? (detail.version !== detail.license.installed_version ? 'update' : 'installed')
							: (detail.license.revoked === 1 ? 'revoked' : 'install'))
						: 'get'}
					{@const detailActionLoading = actionLoading === detail.plugin_id}

					<!-- Close button -->
					<button
						onclick={closeDetail}
						class="absolute top-3 right-3 w-8 h-8 rounded-lg bg-surface-700 text-surface-400
							hover:bg-surface-600 hover:text-surface-200 flex items-center justify-center text-sm z-10"
					>
						{'\u{2715}'}
					</button>

					<div class="p-6 space-y-6">
						<!-- Header -->
						<div class="flex items-start gap-4 pr-10">
							<span class="text-4xl">{detail.icon ?? '\u{1F4E6}'}</span>
							<div>
								<h2 class="text-lg font-bold text-surface-100">{detail.name}</h2>
								<div class="text-xs text-surface-500">{detail.org}</div>
								<div class="text-xs text-surface-400 mt-1">v{detail.version}</div>
							</div>
						</div>

						{#if detail.description}
							<p class="text-sm text-surface-300 leading-relaxed">{detail.description}</p>
						{/if}

						<!-- Action button -->
						<button
							onclick={() => {
								const asItem: CatalogItem = {
									...detail,
									license_id: detail.license?.license_id ?? null,
									installed: detail.license?.installed ?? null,
									installed_version: detail.license?.installed_version ?? null
								};
								handleAction(asItem);
							}}
							disabled={detailActionLoading || detailAction === 'revoked'}
							class="w-full py-2.5 rounded-lg text-sm font-medium transition-colors
								{detailActionLoading
								? 'bg-surface-600 text-surface-400 cursor-wait'
								: detailAction === 'get'
									? 'bg-accent-600 text-surface-50 hover:bg-accent-500'
									: detailAction === 'install'
										? 'bg-success-500 text-surface-50 hover:bg-success-400'
										: detailAction === 'installed'
											? 'bg-surface-700 text-surface-300 hover:bg-danger-500/20 hover:text-danger-400 border border-surface-600'
											: detailAction === 'update'
												? 'bg-accent-600 text-surface-50 hover:bg-accent-500'
												: 'bg-surface-700 text-surface-500 cursor-not-allowed'}"
						>
							{#if detailActionLoading}
								Processing...
							{:else if detailAction === 'get'}
								Get (Free)
							{:else if detailAction === 'install'}
								Install
							{:else if detailAction === 'installed'}
								Remove Plugin
							{:else if detailAction === 'update'}
								Update to v{detail.version}
							{:else}
								License Revoked
							{/if}
						</button>

						<!-- Tags -->
						{#if parseTags(detail.tags).length > 0}
							<div>
								<h3 class="text-[11px] text-surface-500 uppercase tracking-wider mb-2">Tags</h3>
								<div class="flex gap-1.5 flex-wrap">
									{#each parseTags(detail.tags) as tag}
										<span class="text-xs px-2 py-1 rounded-lg bg-surface-700 text-surface-300 border border-surface-600">
											{tag}
										</span>
									{/each}
								</div>
							</div>
						{/if}

						<!-- Info grid -->
						<div class="space-y-3">
							<h3 class="text-[11px] text-surface-500 uppercase tracking-wider">Details</h3>
							<div class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-xs">
								<span class="text-surface-500">OCI Image</span>
								<span class="text-surface-300 font-mono break-all">{detail.oci_image}</span>

								{#if detail.publisher_identity}
									<span class="text-surface-500">Publisher</span>
									<span class="text-surface-300 font-mono break-all">{detail.publisher_identity}</span>
								{/if}

								{#if detail.homepage}
									<span class="text-surface-500">Homepage</span>
									<span class="text-accent-400 break-all">{detail.homepage}</span>
								{/if}

								{#if detail.min_daemon_version}
									<span class="text-surface-500">Min Daemon</span>
									<span class="text-surface-300">v{detail.min_daemon_version}</span>
								{/if}
							</div>
						</div>

						<!-- License info -->
						{#if detail.license}
							<div class="space-y-3">
								<h3 class="text-[11px] text-surface-500 uppercase tracking-wider">License</h3>
								<div class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-xs">
									<span class="text-surface-500">Status</span>
									<span class="{detail.license.revoked ? 'text-danger-400' : 'text-success-400'}">
										{detail.license.revoked ? 'Revoked' : 'Active'}
									</span>

									<span class="text-surface-500">Granted</span>
									<span class="text-surface-300">{new Date(detail.license.granted_at).toLocaleDateString()}</span>

									{#if detail.license.installed === 1}
										<span class="text-surface-500">Installed</span>
										<span class="text-surface-300">
											v{detail.license.installed_version}
											{#if detail.license.installed_at}
												 ({new Date(detail.license.installed_at).toLocaleDateString()})
											{/if}
										</span>
									{/if}

									{#if detail.license.upgraded_at}
										<span class="text-surface-500">Last Upgrade</span>
										<span class="text-surface-300">{new Date(detail.license.upgraded_at).toLocaleDateString()}</span>
									{/if}
								</div>
							</div>
						{/if}
					</div>
				{/if}
			</div>
		{/if}
	</div>
</div>
