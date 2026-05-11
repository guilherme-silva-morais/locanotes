import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { persistLocale, SUPPORTED_LOCALES, type AppLocale } from '@/i18n'

// Composable wrapper around vue-i18n's `locale` ref that also persists the
// user's choice to localStorage. Components import `setLocale` and the active
// locale via `current` (computed) so changes propagate reactively everywhere.
export function useLocale() {
  const { locale } = useI18n()

  const current = computed<AppLocale>(() => locale.value as AppLocale)

  function setLocale(code: AppLocale) {
    locale.value = code
    persistLocale(code)
  }

  return {
    current,
    setLocale,
    options: SUPPORTED_LOCALES,
  }
}
