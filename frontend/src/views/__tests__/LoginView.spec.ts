import { describe, it, expect, vi } from 'vitest'
import { flushPromises } from '@vue/test-utils'
import { http, HttpResponse, delay } from 'msw'
import LoginView from '@/views/LoginView.vue'
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
  email = 'alice@example.com',
  password = 'Password123',
) {
  await wrapper.find('[data-testid="email"]').setValue(email)
  await wrapper.find('[data-testid="password"]').setValue(password)
  await wrapper.find('form').trigger('submit')
}

describe('LoginView', () => {
  it('renders the login form', async () => {
    const { wrapper } = await mountView(LoginView)
    expect(wrapper.find('[data-testid="email"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="password"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="submit"]').exists()).toBe(true)
  })

  it('keeps the submit button disabled while either input is empty', async () => {
    const { wrapper } = await mountView(LoginView)
    const submit = wrapper.find('[data-testid="submit"]')
    expect(submit.attributes('disabled')).toBeDefined()

    await wrapper.find('[data-testid="email"]').setValue('a@b.com')
    expect(submit.attributes('disabled')).toBeDefined()

    await wrapper.find('[data-testid="password"]').setValue('Password123')
    expect(submit.attributes('disabled')).toBeUndefined()
  })

  it('logs in, authenticates the store, and redirects to /notes on success', async () => {
    mswServer.use(http.post(`${API}/auth/login`, () => HttpResponse.json(authResponse)))

    const { wrapper, router } = await mountView(LoginView)
    await fillAndSubmit(wrapper)
    await flushPromises()

    expect(useAuthStore().isAuthenticated).toBe(true)
    expect(router.currentRoute.value.path).toBe('/notes')
  })

  it('redirects to the path from the `?redirect` query after login', async () => {
    mswServer.use(http.post(`${API}/auth/login`, () => HttpResponse.json(authResponse)))

    // /notes/42 isn't a real route in this app yet; we spy on router.push to
    // assert intent without depending on the final resolved route.
    const { wrapper, router } = await mountView(LoginView, {}, '/login?redirect=/notes/42')
    const pushSpy = vi.spyOn(router, 'push')

    await fillAndSubmit(wrapper)
    await flushPromises()

    expect(pushSpy).toHaveBeenCalledWith('/notes/42')
  })

  it('shows the generic server error inline (not in an alert) on 401', async () => {
    mswServer.use(
      http.post(`${API}/auth/login`, () =>
        HttpResponse.json({ error: 'Email ou senha incorretos' }, { status: 401 }),
      ),
    )

    const { wrapper } = await mountView(LoginView)
    await fillAndSubmit(wrapper, 'a@b.com', 'wrong')
    await flushPromises()

    const err = wrapper.find('[data-testid="form-error"]')
    expect(err.exists()).toBe(true)
    expect(err.text()).toBe('Email ou senha incorretos')
    expect(useAuthStore().isAuthenticated).toBe(false)
  })

  it('shows a friendly message on network failure (no server error body)', async () => {
    mswServer.use(http.post(`${API}/auth/login`, () => HttpResponse.error()))

    const { wrapper } = await mountView(LoginView)
    await fillAndSubmit(wrapper)
    await flushPromises()

    expect(wrapper.find('[data-testid="form-error"]').text()).toMatch(/erro de conexão/i)
  })

  it('shows a specific message on 429 rate-limited responses', async () => {
    mswServer.use(
      http.post(`${API}/auth/login`, () =>
        HttpResponse.json({ error: 'Muitas tentativas. Tente novamente em instantes.' }, { status: 429 }),
      ),
    )

    const { wrapper } = await mountView(LoginView)
    await fillAndSubmit(wrapper)
    await flushPromises()

    expect(wrapper.find('[data-testid="form-error"]').text()).toMatch(/muitas tentativas/i)
  })

  it('disables the submit button while the request is in flight', async () => {
    mswServer.use(
      http.post(`${API}/auth/login`, async () => {
        await delay(50)
        return HttpResponse.json(authResponse)
      }),
    )

    const { wrapper } = await mountView(LoginView)
    await fillAndSubmit(wrapper)
    // The submit handler has run synchronously up to `await auth.login(...)`;
    // loading is true here, before the response arrives.
    await wrapper.vm.$nextTick()
    expect(wrapper.find('[data-testid="submit"]').attributes('disabled')).toBeDefined()

    await flushPromises()
    // After it resolves, the button is no longer disabled (and the user is gone — redirect).
  })
})
