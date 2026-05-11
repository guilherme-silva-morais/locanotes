import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import LanguageSwitcher from '@/components/LanguageSwitcher.vue'
import { i18n } from '@/i18n'

function mountSwitcher() {
  return mount(LanguageSwitcher, { global: { plugins: [i18n] } })
}

describe('LanguageSwitcher', () => {
  it('renders an option for each supported locale', () => {
    const wrapper = mountSwitcher()
    const options = wrapper.findAll('option').map((o) => o.attributes('value'))
    expect(options).toEqual(['pt-BR', 'en'])
  })

  it('reflects the active locale in the select value', () => {
    i18n.global.locale.value = 'en'
    const wrapper = mountSwitcher()
    const select = wrapper.find('[data-testid="language-switcher"]')
      .element as HTMLSelectElement
    expect(select.value).toBe('en')
  })

  it('updates i18n and localStorage when the user picks a new locale', async () => {
    i18n.global.locale.value = 'pt-BR'
    const wrapper = mountSwitcher()

    await wrapper.find('[data-testid="language-switcher"]').setValue('en')

    expect(i18n.global.locale.value).toBe('en')
    expect(localStorage.getItem('locanotes:locale')).toBe('en')
  })
})
