import axios from 'axios'
import { i18n } from '@/i18n'

// Build an Accept-Language value from the current i18n locale so server-side
// validation errors and other localized messages come back in the user's
// language. Backend understands "en" and "pt-BR" (pt-BR is the default).
function buildAcceptLanguage(): string {
  const current = i18n.global.locale.value as string
  const base = current.split('-')[0]
  const fallback = current.startsWith('pt') ? 'en' : 'pt-BR'
  return `${current},${base};q=0.9,${fallback};q=0.5`
}

// A single, app-wide axios instance. Components and stores import this
// (or the typed wrappers in ./auth.ts and ./notes.ts) — never `axios` directly,
// so we have one place to attach interceptors (Authorization, refresh, locale).
export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
  headers: {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  },
})

// Inject Accept-Language per request — picks up locale changes at runtime
// instead of being frozen at module-init time.
apiClient.interceptors.request.use((config) => {
  config.headers['Accept-Language'] = buildAcceptLanguage()
  return config
})
