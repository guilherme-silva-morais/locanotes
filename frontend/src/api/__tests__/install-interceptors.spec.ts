import { describe, it, expect, beforeEach } from 'vitest'
import { http, HttpResponse } from 'msw'
import { apiClient } from '@/api/client'
import { installInterceptors } from '@/api/install-interceptors'
import { useAuthStore } from '@/stores/auth'
import { mswServer } from '@/__tests__/setup'

const API = 'http://localhost:3000/api/v1'

const userPayload = { id: 1, email_address: 'alice@example.com' }

describe('apiClient interceptors', () => {
  beforeEach(() => {
    // Reset axios interceptors between tests so we don't stack them.
    apiClient.interceptors.request.clear()
    apiClient.interceptors.response.clear()
    installInterceptors()
  })

  describe('request interceptor', () => {
    it('attaches Authorization: Bearer when the user is authenticated', async () => {
      const auth = useAuthStore()
      auth.setAuth({
        user: userPayload,
        tokens: { access_token: 'token-A', refresh_token: 'r-A' },
      })

      let receivedAuth: string | null = null
      mswServer.use(
        http.get(`${API}/notes`, ({ request }) => {
          receivedAuth = request.headers.get('Authorization')
          return HttpResponse.json({ data: [], next_cursor: null, has_more: false })
        }),
      )

      await apiClient.get('/notes')
      expect(receivedAuth).toBe('Bearer token-A')
    })

    it('does not attach Authorization when the user is not authenticated', async () => {
      let receivedAuth: string | null = 'placeholder'
      mswServer.use(
        http.post(`${API}/auth/login`, ({ request }) => {
          receivedAuth = request.headers.get('Authorization')
          return HttpResponse.json({})
        }),
      )

      await apiClient.post('/auth/login', {})
      expect(receivedAuth).toBeNull()
    })
  })

  describe('response interceptor — 401 handling', () => {
    it('refreshes the access token on 401 and retries the original request', async () => {
      const auth = useAuthStore()
      auth.setAuth({
        user: userPayload,
        tokens: { access_token: 'old-access', refresh_token: 'r-A' },
      })

      let notesCalls = 0
      const tokensSeen: (string | null)[] = []

      mswServer.use(
        http.get(`${API}/notes`, ({ request }) => {
          notesCalls += 1
          tokensSeen.push(request.headers.get('Authorization'))
          if (notesCalls === 1) {
            return HttpResponse.json({ error: 'Não autorizado' }, { status: 401 })
          }
          return HttpResponse.json({ data: [], next_cursor: null, has_more: false })
        }),
        http.post(`${API}/auth/refresh`, () =>
          HttpResponse.json({ access_token: 'new-access' }, { status: 200 }),
        ),
      )

      const response = await apiClient.get('/notes')

      expect(response.status).toBe(200)
      expect(notesCalls).toBe(2)
      expect(tokensSeen[0]).toBe('Bearer old-access')
      expect(tokensSeen[1]).toBe('Bearer new-access')
      expect(auth.accessToken).toBe('new-access')
    })

    it('does NOT attempt refresh on 401 against auth endpoints (no infinite loop)', async () => {
      const auth = useAuthStore()
      auth.setAuth({
        user: userPayload,
        tokens: { access_token: 'a', refresh_token: 'r' },
      })

      let refreshCalls = 0
      mswServer.use(
        http.post(`${API}/auth/login`, () =>
          HttpResponse.json({ error: 'Email ou senha incorretos' }, { status: 401 }),
        ),
        http.post(`${API}/auth/refresh`, () => {
          refreshCalls += 1
          return HttpResponse.json({ access_token: 'new' }, { status: 200 })
        }),
      )

      await expect(apiClient.post('/auth/login', {})).rejects.toMatchObject({
        response: { status: 401 },
      })
      expect(refreshCalls).toBe(0)
    })

    it('clears auth state when refresh itself fails', async () => {
      const auth = useAuthStore()
      auth.setAuth({
        user: userPayload,
        tokens: { access_token: 'a', refresh_token: 'r' },
      })

      mswServer.use(
        http.get(`${API}/notes`, () => HttpResponse.json({}, { status: 401 })),
        http.post(`${API}/auth/refresh`, () => HttpResponse.json({}, { status: 401 })),
      )

      await expect(apiClient.get('/notes')).rejects.toMatchObject({
        response: { status: 401 },
      })
      expect(auth.isAuthenticated).toBe(false)
      expect(localStorage.getItem('locanotes:auth')).toBeNull()
    })

    it('does not refresh when there is no refresh token (unauthenticated 401)', async () => {
      let refreshCalls = 0
      mswServer.use(
        http.get(`${API}/notes`, () => HttpResponse.json({}, { status: 401 })),
        http.post(`${API}/auth/refresh`, () => {
          refreshCalls += 1
          return HttpResponse.json({})
        }),
      )

      await expect(apiClient.get('/notes')).rejects.toMatchObject({
        response: { status: 401 },
      })
      expect(refreshCalls).toBe(0)
    })
  })

  describe('response interceptor — non-401 errors', () => {
    it('passes through other errors unchanged', async () => {
      const auth = useAuthStore()
      auth.setAuth({
        user: userPayload,
        tokens: { access_token: 'a', refresh_token: 'r' },
      })

      mswServer.use(
        http.post(`${API}/notes`, () =>
          HttpResponse.json({ errors: { title: ["can't be blank"] } }, { status: 422 }),
        ),
      )

      await expect(apiClient.post('/notes', { title: '' })).rejects.toMatchObject({
        response: { status: 422 },
      })
    })
  })
})
