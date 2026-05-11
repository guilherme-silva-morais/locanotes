import { ref } from 'vue'

export type ThemePref = 'system' | 'light' | 'dark'

const STORAGE_KEY = 'locanotes:theme'

function safeRead(): ThemePref {
  try {
    const v = localStorage.getItem(STORAGE_KEY)
    if (v === 'light' || v === 'dark' || v === 'system') return v
  } catch {
    // localStorage unavailable
  }
  return 'system'
}

function applyTheme(pref: ThemePref): void {
  if (typeof document === 'undefined') return
  if (pref === 'system') {
    document.documentElement.removeAttribute('data-theme')
  } else {
    document.documentElement.setAttribute('data-theme', pref)
  }
}

// Module-level reactive ref, initialized once. All components see the same value.
const theme = ref<ThemePref>(safeRead())

// Apply on module load so the page boots with the user's choice already active.
applyTheme(theme.value)

export function useTheme() {
  function setTheme(pref: ThemePref) {
    theme.value = pref
    applyTheme(pref)
    try {
      localStorage.setItem(STORAGE_KEY, pref)
    } catch {
      // ignore — localStorage unavailable
    }
  }

  return { theme, setTheme }
}
