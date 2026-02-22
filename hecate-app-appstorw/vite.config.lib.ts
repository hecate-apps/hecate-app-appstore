import { svelte } from '@sveltejs/vite-plugin-svelte';
import { defineConfig } from 'vite';
import path from 'path';

export default defineConfig({
	plugins: [svelte({
		compilerOptions: {
			css: 'injected',
			customElement: true
		}
	})],
	resolve: {
		alias: {
			$lib: path.resolve(__dirname, 'src/lib')
		}
	},
	build: {
		lib: {
			entry: 'src/lib/AppstoreStudio.svelte',
			formats: ['es'],
			fileName: () => 'component.js'
		},
		outDir: 'dist',
		emptyOutDir: true
	}
});
