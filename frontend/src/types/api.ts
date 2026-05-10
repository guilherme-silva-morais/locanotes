// Contract shapes returned by the Rails API. Keep these in sync with the
// serializers in `backend/app/controllers/api/v1/*`.

export interface User {
  id: number
  email_address: string
}

export interface Note {
  id: number
  title: string
  content: string | null
  created_at: string // ISO 8601
  updated_at: string // ISO 8601
}

export interface Paginated<T> {
  data: T[]
  next_cursor: string | null
  has_more: boolean
}

export interface AuthTokens {
  access_token: string
  refresh_token: string
}

export interface AuthResponse extends AuthTokens {
  user: User
}

export interface RefreshResponse {
  access_token: string
}

// Two error shapes the API may return:
//   { error: "..." }                              — generic, e.g. 401/429/400
//   { errors: { field: ["msg1", "msg2"] } }       — validation errors (422)
export interface GenericApiError {
  error: string
}

export interface ValidationApiError {
  errors: Record<string, string[]>
}

export type ApiErrorBody = GenericApiError | ValidationApiError

export function isValidationError(body: ApiErrorBody): body is ValidationApiError {
  return 'errors' in body
}
