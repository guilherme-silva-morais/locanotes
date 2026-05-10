import { apiClient } from './client'
import { useAuthStore } from '@/stores/auth'

// Endpoints that must NEVER trigger an auto-refresh on 401 — otherwise a
// failed refresh would loop forever.
const AUTH_PATH_SUFFIXES = ['/auth/register', '/auth/login', '/auth/refresh', '/auth/logout']

function isAuthEndpoint(url: string | undefined): boolean {
  if (!url) return false
  return AUTH_PATH_SUFFIXES.some((suffix) => url.endsWith(suffix))
}

export function installInterceptors() {
  // Request: attach the current access token, if any.
  apiClient.interceptors.request.use((config) => {
    const auth = useAuthStore()
    if (auth.accessToken) {
      config.headers.Authorization = `Bearer ${auth.accessToken}`
    }
    return config
  })

  // Response: on 401 against a non-auth endpoint, attempt one refresh and
  // retry the original request. If the refresh fails, clear local auth state
  // (caller will redirect to /login via router guard).
  apiClient.interceptors.response.use(
    (response) => response,
    async (error) => {
      const auth = useAuthStore()
      const originalRequest = error.config
      const status = error.response?.status

      const canRetry =
        status === 401 &&
        !isAuthEndpoint(originalRequest?.url) &&
        !originalRequest?._retry &&
        auth.refreshToken !== null

      if (canRetry) {
        originalRequest._retry = true
        try {
          const newAccessToken = await auth.refresh()
          originalRequest.headers.Authorization = `Bearer ${newAccessToken}`
          return apiClient(originalRequest)
        } catch {
          auth.clearAuth()
          return Promise.reject(error)
        }
      }

      return Promise.reject(error)
    },
  )
}
