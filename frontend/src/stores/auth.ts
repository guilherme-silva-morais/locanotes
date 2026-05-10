import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { authApi, type LoginParams, type RegisterParams } from '@/api/auth'
import type { User, AuthTokens } from '@/types/api'

const STORAGE_KEY = 'locanotes:auth'

interface StoredAuth {
  user: User | null
  tokens: AuthTokens | null
}

// localStorage is the persistence layer — tokens survive reloads. Refresh
// tokens in httpOnly cookies would be safer in production (XSS-proof), but
// localStorage is acceptable for this scope (see README security notes).
function loadFromStorage(): StoredAuth {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return { user: null, tokens: null }
    const parsed = JSON.parse(raw)
    return { user: parsed.user ?? null, tokens: parsed.tokens ?? null }
  } catch {
    return { user: null, tokens: null }
  }
}

function persist(snapshot: StoredAuth) {
  if (snapshot.user && snapshot.tokens) {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(snapshot))
  } else {
    localStorage.removeItem(STORAGE_KEY)
  }
}

export const useAuthStore = defineStore('auth', () => {
  const initial = loadFromStorage()
  const user = ref<User | null>(initial.user)
  const tokens = ref<AuthTokens | null>(initial.tokens)

  const isAuthenticated = computed(() => user.value !== null && tokens.value !== null)
  const accessToken = computed(() => tokens.value?.access_token ?? null)
  const refreshToken = computed(() => tokens.value?.refresh_token ?? null)

  function setAuth(payload: { user: User; tokens: AuthTokens }) {
    user.value = payload.user
    tokens.value = payload.tokens
    persist({ user: user.value, tokens: tokens.value })
  }

  function clearAuth() {
    user.value = null
    tokens.value = null
    persist({ user: null, tokens: null })
  }

  async function login(params: LoginParams) {
    const data = await authApi.login(params)
    setAuth({
      user: data.user,
      tokens: { access_token: data.access_token, refresh_token: data.refresh_token },
    })
    return data
  }

  async function register(params: RegisterParams) {
    const data = await authApi.register(params)
    setAuth({
      user: data.user,
      tokens: { access_token: data.access_token, refresh_token: data.refresh_token },
    })
    return data
  }

  // Server-side logout (destroys the Session row); local state is cleared even
  // if the server call fails (e.g. token already revoked elsewhere).
  async function logout() {
    try {
      if (tokens.value) {
        await authApi.logout()
      }
    } catch {
      // swallow — clearing local state below is what matters
    } finally {
      clearAuth()
    }
  }

  // Used by the response interceptor on 401. Returns the new access token
  // so the caller can retry the original request.
  async function refresh(): Promise<string> {
    if (!tokens.value) throw new Error('No refresh token available')
    const data = await authApi.refresh(tokens.value.refresh_token)
    tokens.value = { ...tokens.value, access_token: data.access_token }
    persist({ user: user.value, tokens: tokens.value })
    return data.access_token
  }

  return {
    user,
    tokens,
    isAuthenticated,
    accessToken,
    refreshToken,
    setAuth,
    clearAuth,
    login,
    register,
    logout,
    refresh,
  }
})
