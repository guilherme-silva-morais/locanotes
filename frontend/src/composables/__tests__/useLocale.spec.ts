import { describe, it, expect } from 'vitest'
import { defineComponent, h } from 'vue'
import { mount } from '@vue/test-utils'
import { i18n } from '@/i18n'
import { useLocale } from '@/composables/useLocale'

// `useI18n()` only works inside a setup function. We mount a probe component
// to exercise the composable in a real Vue lifecycle, then return its returned
// API for assertions.
function withProbe<T>(fn: () => T): T {
  let api!: T
  const Probe = defineComponent({
    setup() {
      api = fn()
      return () => h('div')
    },
  })
  mount(Probe, { global: { plugins: [i18n] } })
  return api
}

describe('useLocale', () => {
  it('exposes the current i18n locale and the supported options', () => {
    const { current, options } = withProbe(() => useLocale())

    expect(current.value).toBe(i18n.global.locale.value)
    expect(options.map((o) => o.code)).toEqual(['pt-BR', 'en'])
  })

  it('setLocale updates the active i18n locale', () => {
    const { setLocale, current } = withProbe(() => useLocale())

    setLocale('en')
    expect(current.value).toBe('en')
    expect(i18n.global.locale.value).toBe('en')

    setLocale('pt-BR')
    expect(current.value).toBe('pt-BR')
  })

  it('persists the user choice to localStorage', () => {
    const { setLocale } = withProbe(() => useLocale())

    setLocale('en')
    expect(localStorage.getItem('locanotes:locale')).toBe('en')

    setLocale('pt-BR')
    expect(localStorage.getItem('locanotes:locale')).toBe('pt-BR')
  })
})
