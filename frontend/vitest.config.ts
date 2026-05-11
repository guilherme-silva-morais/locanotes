import { fileURLToPath } from 'node:url'
import { mergeConfig, defineConfig, configDefaults } from 'vitest/config'
import viteConfig from './vite.config'

export default mergeConfig(
  viteConfig,
  defineConfig({
    test: {
      environment: 'jsdom',
      exclude: [...configDefaults.exclude, 'e2e/**'],
      root: fileURLToPath(new URL('./', import.meta.url)),
      setupFiles: ['./src/__tests__/setup.ts'],
      // Pin VITE_API_URL for the suite so apiClient has a real baseURL and the
      // absolute handler URLs in MSW (`${API}/...`) match the issued requests.
      // Without this, CI runs (no .env file) leave the baseURL undefined, axios
      // sends relative URLs, and MSW errors every request as unhandled.
      env: {
        VITE_API_URL: 'http://localhost:3000/api/v1',
      },
    },
  }),
)
