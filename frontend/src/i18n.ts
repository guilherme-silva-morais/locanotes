import { createI18n } from 'vue-i18n'
import ptBR from './locales/pt-BR.json'
import en from './locales/en.json'

export type AppLocale = 'pt-BR' | 'en'

export const SUPPORTED_LOCALES: ReadonlyArray<{ code: AppLocale; label: string }> = [
  { code: 'pt-BR', label: 'Português (BR)' },
  { code: 'en', label: 'English' },
]

const LOCALE_STORAGE_KEY = 'locanotes:locale'

export function detectLocale(): AppLocale {
  // 1) Explicit user choice persisted from a previous session.
  try {
    const stored = localStorage.getItem(LOCALE_STORAGE_KEY)
    if (stored === 'pt-BR' || stored === 'en') return stored
  } catch {
    // localStorage may be unavailable (private mode); fall through.
  }

  // 2) Best match against navigator.language.
  if (typeof navigator === 'undefined') return 'pt-BR'
  const tag = navigator.language.toLowerCase()
  if (tag.startsWith('pt')) return 'pt-BR'
  return 'en'
}

export function persistLocale(locale: AppLocale): void {
  try {
    localStorage.setItem(LOCALE_STORAGE_KEY, locale)
  } catch {
    // ignore — localStorage unavailable
  }
}

// Single i18n instance, used by main.ts and exported for direct access in
// non-component code (e.g. the axios client when synthesizing error messages).
export const i18n = createI18n<false>({
  legacy: false,
  locale: detectLocale(),
  fallbackLocale: 'pt-BR',
  messages: {
    'pt-BR': ptBR,
    en,
  },
})

// Convenience helper for use outside Vue components (e.g. axios interceptors).
// Inside <script setup>, prefer the `useI18n()` composable.
export function t(key: string, ...args: unknown[]) {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return (i18n.global.t as any)(key, ...args)
}
