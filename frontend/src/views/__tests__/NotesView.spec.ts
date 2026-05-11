import { describe, it, expect } from 'vitest'
import { flushPromises } from '@vue/test-utils'
import { http, HttpResponse } from 'msw'
import NotesView from '@/views/NotesView.vue'
import { mountView } from '@/test-helpers'
import { mswServer } from '@/__tests__/setup'
import { useAuthStore } from '@/stores/auth'

const API = 'http://localhost:3000/api/v1'

function noteFixture(id: number, overrides: Partial<{ title: string; content: string | null }> = {}) {
  const now = new Date().toISOString()
  return {
    id,
    title: overrides.title ?? `Note ${id}`,
    content: overrides.content ?? `Body of ${id}`,
    created_at: now,
    updated_at: now,
  }
}

function authenticate() {
  const auth = useAuthStore()
  auth.setAuth({
    user: { id: 1, email_address: 'alice@example.com' },
    tokens: { access_token: 'a', refresh_token: 'r' },
  })
}

describe('NotesView', () => {
  it('shows the empty state when the API returns no notes', async () => {
    authenticate()
    mswServer.use(
      http.get(`${API}/notes`, () =>
        HttpResponse.json({ data: [], next_cursor: null, has_more: false }),
      ),
    )

    const { wrapper } = await mountView(NotesView, {}, '/notes')
    await flushPromises()

    expect(wrapper.find('[data-testid="empty"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="notes-list"]').exists()).toBe(false)
    expect(wrapper.find('[data-testid="load-more"]').exists()).toBe(false)
  })

  it('renders the list of notes returned by the API', async () => {
    authenticate()
    mswServer.use(
      http.get(`${API}/notes`, () =>
        HttpResponse.json({
          data: [noteFixture(1, { title: 'First' }), noteFixture(2, { title: 'Second' })],
          next_cursor: null,
          has_more: false,
        }),
      ),
    )

    const { wrapper } = await mountView(NotesView, {}, '/notes')
    await flushPromises()

    const items = wrapper.findAll('[data-testid="note-item"]')
    expect(items).toHaveLength(2)
    expect(items.map((i) => i.find('h3').text())).toEqual(['First', 'Second'])
  })

  it('shows the load-more button when has_more=true', async () => {
    authenticate()
    mswServer.use(
      http.get(`${API}/notes`, () =>
        HttpResponse.json({
          data: [noteFixture(1)],
          next_cursor: 'cursor-1',
          has_more: true,
        }),
      ),
    )

    const { wrapper } = await mountView(NotesView, {}, '/notes')
    await flushPromises()

    expect(wrapper.find('[data-testid="load-more"]').exists()).toBe(true)
  })

  it('appends the next page (does not duplicate or replace items)', async () => {
    authenticate()
    const cursorsReceived: (string | null)[] = []
    let callCount = 0

    mswServer.use(
      http.get(`${API}/notes`, ({ request }) => {
        callCount += 1
        cursorsReceived.push(new URL(request.url).searchParams.get('cursor'))

        if (callCount === 1) {
          return HttpResponse.json({
            data: [noteFixture(1, { title: 'A' }), noteFixture(2, { title: 'B' })],
            next_cursor: 'cursor-1',
            has_more: true,
          })
        }
        return HttpResponse.json({
          data: [noteFixture(3, { title: 'C' })],
          next_cursor: null,
          has_more: false,
        })
      }),
    )

    const { wrapper } = await mountView(NotesView, {}, '/notes')
    await flushPromises()
    expect(wrapper.findAll('[data-testid="note-item"]')).toHaveLength(2)

    await wrapper.find('[data-testid="load-more"]').trigger('click')
    await flushPromises()

    const items = wrapper.findAll('[data-testid="note-item"]')
    expect(items.map((i) => i.find('h3').text())).toEqual(['A', 'B', 'C'])
    // Confirms the second request forwarded the cursor from the first response.
    expect(cursorsReceived).toEqual([null, 'cursor-1'])
  })

  it('hides the load-more button after fetching the last page', async () => {
    authenticate()
    let callCount = 0
    mswServer.use(
      http.get(`${API}/notes`, () => {
        callCount += 1
        if (callCount === 1) {
          return HttpResponse.json({
            data: [noteFixture(1)],
            next_cursor: 'cursor-1',
            has_more: true,
          })
        }
        return HttpResponse.json({
          data: [noteFixture(2)],
          next_cursor: null,
          has_more: false,
        })
      }),
    )

    const { wrapper } = await mountView(NotesView, {}, '/notes')
    await flushPromises()
    await wrapper.find('[data-testid="load-more"]').trigger('click')
    await flushPromises()

    expect(wrapper.find('[data-testid="load-more"]').exists()).toBe(false)
  })

  it('shows an error message when the API fails', async () => {
    authenticate()
    mswServer.use(http.get(`${API}/notes`, () => HttpResponse.error()))

    const { wrapper } = await mountView(NotesView, {}, '/notes')
    await flushPromises()

    expect(wrapper.find('[data-testid="load-error"]').exists()).toBe(true)
  })

  it('displays the current user email in the header', async () => {
    authenticate()
    mswServer.use(
      http.get(`${API}/notes`, () =>
        HttpResponse.json({ data: [], next_cursor: null, has_more: false }),
      ),
    )

    const { wrapper } = await mountView(NotesView, {}, '/notes')
    await flushPromises()

    expect(wrapper.find('.user-email').text()).toBe('alice@example.com')
  })

  it('logs out the user and redirects to /login when the logout button is clicked', async () => {
    authenticate()
    mswServer.use(
      http.get(`${API}/notes`, () =>
        HttpResponse.json({ data: [], next_cursor: null, has_more: false }),
      ),
      http.delete(`${API}/auth/logout`, () => new HttpResponse(null, { status: 204 })),
    )

    const { wrapper, router } = await mountView(NotesView, {}, '/notes')
    await flushPromises()

    await wrapper.find('[data-testid="logout"]').trigger('click')
    await flushPromises()

    expect(useAuthStore().isAuthenticated).toBe(false)
    expect(router.currentRoute.value.path).toBe('/login')
  })
})
