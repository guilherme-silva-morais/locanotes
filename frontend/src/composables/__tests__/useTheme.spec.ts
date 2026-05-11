import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { useTheme } from '@/composables/useTheme'

const KEY = 'locanotes:theme'

describe('useTheme', () => {
  beforeEach(() => {
    document.documentElement.removeAttribute('data-theme')
    localStorage.removeItem(KEY)
  })

  afterEach(() => {
    document.documentElement.removeAttribute('data-theme')
  })

  it('exposes the current theme preference', () => {
    const { theme } = useTheme()
    // The default at module load was 'system'; specs may have mutated it.
    expect(['system', 'light', 'dark']).toContain(theme.value)
  })

  it('setTheme("dark") sets data-theme="dark" on <html> and persists', () => {
    const { setTheme } = useTheme()
    setTheme('dark')
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark')
    expect(localStorage.getItem(KEY)).toBe('dark')
  })

  it('setTheme("light") sets data-theme="light" on <html> and persists', () => {
    const { setTheme } = useTheme()
    setTheme('light')
    expect(document.documentElement.getAttribute('data-theme')).toBe('light')
    expect(localStorage.getItem(KEY)).toBe('light')
  })

  it('setTheme("system") removes data-theme so prefers-color-scheme takes over', () => {
    const { setTheme } = useTheme()
    setTheme('dark')
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark')

    setTheme('system')
    expect(document.documentElement.hasAttribute('data-theme')).toBe(false)
    expect(localStorage.getItem(KEY)).toBe('system')
  })

  it('changes to theme are reactive across consumers', () => {
    const a = useTheme()
    const b = useTheme()
    a.setTheme('dark')
    expect(b.theme.value).toBe('dark')
  })
})
