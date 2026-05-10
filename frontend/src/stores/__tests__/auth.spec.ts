import { describe, it, expect } from 'vitest'
import { http, HttpResponse } from 'msw'
import { useAuthStore } from '@/stores/auth'
import { mswServer } from '@/__tests__/setup'

const API = 'http://localhost:3000/api/v1'

const userPayload = { id: 1, email_address: 'alice@example.com' }
const tokensPayload = { access_token: 'access-1', refresh_token: 'refresh-1' }
const authResponseBody = { ...tokensPayload, user: userPayload }

describe('useAuthStore', () => {
  describe('initial state', () => {
    it('starts unauthenticated when localStorage is empty', () => {
      const auth = useAuthStore()
      expect(auth.user).toBeNull()
      expect(auth.tokens).toBeNull()
      expect(auth.isAuthenticated).toBe(false)
      expect(auth.accessToken).toBeNull()
    })

    it('hydrates from localStorage if a session is persisted', () => {
      localStorage.setItem(
        'locanotes:auth',
        JSON.stringify({ user: userPayload, tokens: tokensPayload }),
      )
      const auth = useAuthStore()
      expect(auth.isAuthenticated).toBe(true)
      expect(auth.user?.email_address).toBe('alice@example.com')
      expect(auth.accessToken).toBe('access-1')
    })
  })

  describe('login', () => {
    it('stores user + tokens on success and persists to localStorage', async () => {
      mswServer.use(
        http.post(`${API}/auth/login`, () => HttpResponse.json(authResponseBody, { status: 200 })),
      )
      const auth = useAuthStore()

      await auth.login({ email_address: 'alice@example.com', password: 'Password123' })

      expect(auth.isAuthenticated).toBe(true)
      expect(auth.accessToken).toBe('access-1')
      expect(JSON.parse(localStorage.getItem('locanotes:auth') ?? '{}').user.id).toBe(1)
    })

    it('rejects and leaves the store empty when credentials are invalid', async () => {
      mswServer.use(
        http.post(`${API}/auth/login`, () =>
          HttpResponse.json({ error: 'Email ou senha incorretos' }, { status: 401 }),
        ),
      )
      const auth = useAuthStore()

      await expect(
        auth.login({ email_address: 'alice@example.com', password: 'wrong' }),
      ).rejects.toMatchObject({ response: { status: 401 } })

      expect(auth.isAuthenticated).toBe(false)
      expect(localStorage.getItem('locanotes:auth')).toBeNull()
    })
  })

  describe('register', () => {
    it('stores user + tokens and persists', async () => {
      mswServer.use(
        http.post(`${API}/auth/register`, () =>
          HttpResponse.json(authResponseBody, { status: 201 }),
        ),
      )
      const auth = useAuthStore()

      await auth.register({
        email_address: 'alice@example.com',
        password: 'Password123',
        password_confirmation: 'Password123',
      })

      expect(auth.isAuthenticated).toBe(true)
      expect(auth.user?.id).toBe(1)
    })
  })

  describe('logout', () => {
    it('calls the server logout, clears state, and removes localStorage', async () => {
      mswServer.use(http.delete(`${API}/auth/logout`, () => new HttpResponse(null, { status: 204 })))
      const auth = useAuthStore()
      auth.setAuth({ user: userPayload, tokens: tokensPayload })

      await auth.logout()

      expect(auth.isAuthenticated).toBe(false)
      expect(localStorage.getItem('locanotes:auth')).toBeNull()
    })

    it('still clears local state even if the server logout fails', async () => {
      mswServer.use(
        http.delete(`${API}/auth/logout`, () =>
          HttpResponse.json({ error: 'Não autorizado' }, { status: 401 }),
        ),
      )
      const auth = useAuthStore()
      auth.setAuth({ user: userPayload, tokens: tokensPayload })

      await auth.logout()
      expect(auth.isAuthenticated).toBe(false)
    })
  })

  describe('refresh', () => {
    it('replaces only the access_token, keeping the refresh_token', async () => {
      mswServer.use(
        http.post(`${API}/auth/refresh`, () =>
          HttpResponse.json({ access_token: 'access-2' }, { status: 200 }),
        ),
      )
      const auth = useAuthStore()
      auth.setAuth({ user: userPayload, tokens: tokensPayload })

      const newAccess = await auth.refresh()

      expect(newAccess).toBe('access-2')
      expect(auth.accessToken).toBe('access-2')
      expect(auth.refreshToken).toBe('refresh-1')
    })

    it('rejects when the refresh endpoint returns 401', async () => {
      mswServer.use(
        http.post(`${API}/auth/refresh`, () => HttpResponse.json({}, { status: 401 })),
      )
      const auth = useAuthStore()
      auth.setAuth({ user: userPayload, tokens: tokensPayload })

      await expect(auth.refresh()).rejects.toMatchObject({ response: { status: 401 } })
    })

    it('throws synchronously when there is no refresh token', async () => {
      const auth = useAuthStore()
      await expect(auth.refresh()).rejects.toThrow(/no refresh token/i)
    })
  })

  describe('clearAuth', () => {
    it('wipes both state and localStorage', () => {
      const auth = useAuthStore()
      auth.setAuth({ user: userPayload, tokens: tokensPayload })
      expect(localStorage.getItem('locanotes:auth')).not.toBeNull()

      auth.clearAuth()
      expect(auth.isAuthenticated).toBe(false)
      expect(localStorage.getItem('locanotes:auth')).toBeNull()
    })
  })
})
