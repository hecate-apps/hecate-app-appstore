<script lang="ts">
	import '../app.css';
	import type { PluginApi } from '$lib/types.js';

	// Dev-mode mock API that proxies to the local daemon
	async function mockGet(path: string) {
		const res = await fetch(`http://localhost:8095${path}`);
		if (!res.ok) throw new Error(`GET ${path}: ${res.status}`);
		return res.json();
	}

	async function mockPost(path: string, body: unknown) {
		const res = await fetch(`http://localhost:8095${path}`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify(body)
		});
		if (!res.ok) throw new Error(`POST ${path}: ${res.status}`);
		return res.json();
	}

	async function mockDel(path: string) {
		const res = await fetch(`http://localhost:8095${path}`, { method: 'DELETE' });
		if (!res.ok) throw new Error(`DELETE ${path}: ${res.status}`);
		return res.json();
	}

	const mockApi: PluginApi = { get: mockGet, post: mockPost, del: mockDel };
</script>

<appstore-studio api={mockApi}></appstore-studio>
