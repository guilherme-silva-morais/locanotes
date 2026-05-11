import { describe, it, expect, beforeEach } from 'vitest'
import { mount } from '@vue/test-utils'
import ThemeSwitcher from '@/components/ThemeSwitcher.vue'
import { i18n } from '@/i18n'

function mountSwitcher() {
  return mount(ThemeSwitcher, { global: { plugins: [i18n] } })
}

describe('ThemeSwitcher', () => {
  beforeEach(() => {
    document.documentElement.removeAttribute('data-theme')
    localStorage.removeItem('locanotes:theme')
  })

  it('renders system, light, and dark options', () => {
    const wrapper = mountSwitcher()
    const values = wrapper.findAll('option').map((o) => o.attributes('value'))
    expect(values).toEqual(['system', 'light', 'dark'])
  })

  it('applies data-theme to <html> and persists when the user picks "dark"', async () => {
    const wrapper = mountSwitcher()
    await wrapper.find('[data-testid="theme-switcher"]').setValue('dark')
    expect(document.documentElement.getAttribute('data-theme')).toBe('dark')
    expect(localStorage.getItem('locanotes:theme')).toBe('dark')
  })

  it('removes data-theme when the user picks "system"', async () => {
    const wrapper = mountSwitcher()
    await wrapper.find('[data-testid="theme-switcher"]').setValue('dark')
    await wrapper.find('[data-testid="theme-switcher"]').setValue('system')
    expect(document.documentElement.hasAttribute('data-theme')).toBe(false)
    expect(localStorage.getItem('locanotes:theme')).toBe('system')
  })
})
