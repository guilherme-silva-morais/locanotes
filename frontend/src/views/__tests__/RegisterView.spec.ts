import { describe, it, expect } from 'vitest'
import { flushPromises } from '@vue/test-utils'
import { http, HttpResponse } from 'msw'
import RegisterView from '@/views/RegisterView.vue'
import { mountView } from '@/test-helpers'
import { mswServer } from '@/__tests__/setup'
import { useAuthStore } from '@/stores/auth'

const API = 'http://localhost:3000/api/v1'

const authResponse = {
  access_token: 'a',
  refresh_token: 'r',
  user: { id: 1, email_address: 'alice@example.com' },
}

async function fillAndSubmit(
  wrapper: Awaited<ReturnType<typeof mountView>>['wrapper'],
  overrides: Partial<{ email: string; password: string; confirmation: string }> = {},
) {
  const { email = 'alice@example.com', password = 'Password123', confirmation = 'Password123' } =
    overrides
  await wrapper.find('[data-testid="email"]').setValue(email)
  await wrapper.find('[data-testid="password"]').setValue(password)
  await wrapper.find('[data-testid="password-confirmation"]').setValue(confirmation)
  await wrapper.find('form').trigger('submit')
}

describe('RegisterView', () => {
  it('renders the register form with all three fields', async () => {
    const { wrapper } = await mountView(RegisterView, {}, '/register')
    expect(wrapper.find('[data-testid="email"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="password"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="password-confirmation"]').exists()).toBe(true)
  })

  it('keeps submit disabled until all three fields are filled', async () => {
    const { wrapper } = await mountView(RegisterView, {}, '/register')
    const submit = wrapper.find('[data-testid="submit"]')
    expect(submit.attributes('disabled')).toBeDefined()

    await wrapper.find('[data-testid="email"]').setValue('a@b.com')
    await wrapper.find('[data-testid="password"]').setValue('Password123')
    expect(submit.attributes('disabled')).toBeDefined()

    await wrapper.find('[data-testid="password-confirmation"]').setValue('Password123')
    expect(submit.attributes('disabled')).toBeUndefined()
  })

  it('registers and redirects to /notes on success', async () => {
    mswServer.use(http.post(`${API}/auth/register`, () => HttpResponse.json(authResponse, { status: 201 })))

    const { wrapper, router } = await mountView(RegisterView, {}, '/register')
    await fillAndSubmit(wrapper)
    await flushPromises()

    expect(useAuthStore().isAuthenticated).toBe(true)
    expect(router.currentRoute.value.path).toBe('/notes')
  })

  it('shows server validation errors inline by field on 422', async () => {
    mswServer.use(
      http.post(`${API}/auth/register`, () =>
        HttpResponse.json(
          {
            errors: {
              email_address: ['já está em uso'],
              password: ['deve conter ao menos uma letra e um número'],
            },
          },
          { status: 422 },
        ),
      ),
    )

    const { wrapper } = await mountView(RegisterView, {}, '/register')
    await fillAndSubmit(wrapper)
    await flushPromises()

    expect(wrapper.find('[data-testid="email-error"]').text()).toContain('já está em uso')
    expect(wrapper.find('[data-testid="password-error"]').text()).toMatch(/letra.*número/i)
    expect(wrapper.find('[data-testid="form-error"]').exists()).toBe(false)
  })

  it('preserves the form values when the server returns errors', async () => {
    mswServer.use(
      http.post(`${API}/auth/register`, () =>
        HttpResponse.json({ errors: { password: ['too short'] } }, { status: 422 }),
      ),
    )

    const { wrapper } = await mountView(RegisterView, {}, '/register')
    await fillAndSubmit(wrapper, { email: 'kept@example.com' })
    await flushPromises()

    expect(
      (wrapper.find('[data-testid="email"]').element as HTMLInputElement).value,
    ).toBe('kept@example.com')
  })

  it('shows a generic error on 401 (e.g. when registration is disabled or rate-limited)', async () => {
    mswServer.use(
      http.post(`${API}/auth/register`, () =>
        HttpResponse.json({ error: 'Não autorizado' }, { status: 401 }),
      ),
    )

    const { wrapper } = await mountView(RegisterView, {}, '/register')
    await fillAndSubmit(wrapper)
    await flushPromises()

    expect(wrapper.find('[data-testid="form-error"]').text()).toBe('Não autorizado')
  })

  it('shows a friendly message on network failure', async () => {
    mswServer.use(http.post(`${API}/auth/register`, () => HttpResponse.error()))

    const { wrapper } = await mountView(RegisterView, {}, '/register')
    await fillAndSubmit(wrapper)
    await flushPromises()

    expect(wrapper.find('[data-testid="form-error"]').text()).toMatch(/erro de conexão/i)
  })
})
