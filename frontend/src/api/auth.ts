import { apiClient } from './client'
import type { AuthResponse, RefreshResponse } from '@/types/api'

export interface RegisterParams {
  email_address: string
  password: string
  password_confirmation: string
}

export interface LoginParams {
  email_address: string
  password: string
}

export const authApi = {
  register: (params: RegisterParams) =>
    apiClient.post<AuthResponse>('/auth/register', params).then((r) => r.data),

  login: (params: LoginParams) =>
    apiClient.post<AuthResponse>('/auth/login', params).then((r) => r.data),

  refresh: (refresh_token: string) =>
    apiClient.post<RefreshResponse>('/auth/refresh', { refresh_token }).then((r) => r.data),

  logout: () => apiClient.delete<void>('/auth/logout').then((r) => r.data),
}
