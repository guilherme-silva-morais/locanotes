import { describe, it, expect } from 'vitest'
import { flushPromises } from '@vue/test-utils'
import { http, HttpResponse } from 'msw'
import App from '@/App.vue'
import { mountView } from '@/test-helpers'
import { mswServer } from '@/__tests__/setup'
import { useAuthStore } from '@/stores/auth'

const API = 'http://localhost:3000/api/v1'

const userPayload = { id: 1, email_address: 'alice@example.com' }
const tokensPayload = { access_token: 'a', refresh_token: 'r' }

describe('App header', () => {
  it('hides the user email and logout button when not authenticated', async () => {
    const { wrapper } = await mountView(App, {}, '/login')
    expect(wrapper.find('[data-testid="user-email"]').exists()).toBe(false)
    expect(wrapper.find('[data-testid="logout"]').exists()).toBe(false)
  })

  it('shows the user email and logout button when authenticated', async () => {
    const auth = useAuthStore()
    auth.setAuth({ user: userPayload, tokens: tokensPayload })

    // App at /notes renders NotesView, which fetches on mount — stub it.
    mswServer.use(
      http.get(`${API}/notes`, () =>
        HttpResponse.json({ data: [], next_cursor: null, has_more: false }),
      ),
    )

    const { wrapper } = await mountView(App, {}, '/notes')
    expect(wrapper.find('[data-testid="user-email"]').text()).toBe('alice@example.com')
    expect(wrapper.find('[data-testid="logout"]').exists()).toBe(true)
  })

  it('logs out and redirects to /login when the logout button is clicked', async () => {
    const auth = useAuthStore()
    auth.setAuth({ user: userPayload, tokens: tokensPayload })

    mswServer.use(
      http.get(`${API}/notes`, () =>
        HttpResponse.json({ data: [], next_cursor: null, has_more: false }),
      ),
      http.delete(`${API}/auth/logout`, () => new HttpResponse(null, { status: 204 })),
    )

    const { wrapper, router } = await mountView(App, {}, '/notes')
    await flushPromises()
    await wrapper.find('[data-testid="logout"]').trigger('click')
    await flushPromises()

    expect(useAuthStore().isAuthenticated).toBe(false)
    expect(router.currentRoute.value.path).toBe('/login')
  })

  it('renders the LanguageSwitcher in the header', async () => {
    const { wrapper } = await mountView(App, {}, '/login')
    expect(wrapper.find('[data-testid="language-switcher"]').exists()).toBe(true)
  })
})
