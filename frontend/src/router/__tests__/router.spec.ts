import { describe, it, expect, beforeEach } from 'vitest'
import { createRouter, createMemoryHistory, type Router } from 'vue-router'
import { routes, authGuard } from '@/router'
import { useAuthStore } from '@/stores/auth'

function buildRouter(): Router {
  const router = createRouter({
    history: createMemoryHistory(),
    routes,
  })
  router.beforeEach(authGuard)
  return router
}

const userPayload = { id: 1, email_address: 'alice@example.com' }
const tokensPayload = { access_token: 'access', refresh_token: 'refresh' }

describe('router guards', () => {
  let router: Router

  beforeEach(() => {
    router = buildRouter()
  })

  describe('unauthenticated user', () => {
    it('redirects /notes to /login with a redirect query param', async () => {
      await router.push('/notes')
      expect(router.currentRoute.value.name).toBe('login')
      expect(router.currentRoute.value.query.redirect).toBe('/notes')
    })

    it('allows /login', async () => {
      await router.push('/login')
      expect(router.currentRoute.value.name).toBe('login')
    })

    it('allows /register', async () => {
      await router.push('/register')
      expect(router.currentRoute.value.name).toBe('register')
    })

    it('redirects an unknown path to /login (via /notes -> guard)', async () => {
      await router.push('/some-random-path')
      expect(router.currentRoute.value.name).toBe('login')
    })

    it('redirects / to /login (via /notes -> guard)', async () => {
      await router.push('/')
      expect(router.currentRoute.value.name).toBe('login')
    })
  })

  describe('authenticated user', () => {
    beforeEach(() => {
      const auth = useAuthStore()
      auth.setAuth({ user: userPayload, tokens: tokensPayload })
    })

    it('allows /notes', async () => {
      await router.push('/notes')
      expect(router.currentRoute.value.name).toBe('notes')
    })

    it('redirects /login back to /notes (guest-only)', async () => {
      await router.push('/login')
      expect(router.currentRoute.value.name).toBe('notes')
    })

    it('redirects /register back to /notes (guest-only)', async () => {
      await router.push('/register')
      expect(router.currentRoute.value.name).toBe('notes')
    })

    it('redirects / to /notes', async () => {
      await router.push('/')
      expect(router.currentRoute.value.name).toBe('notes')
    })

    it('redirects an unknown path to /notes', async () => {
      await router.push('/some-random-path')
      expect(router.currentRoute.value.name).toBe('notes')
    })
  })
})
