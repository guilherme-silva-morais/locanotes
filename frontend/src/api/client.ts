import axios from 'axios'

// A single, app-wide axios instance. Components and stores import this
// (or the typed wrappers in ./auth.ts and ./notes.ts) — never `axios` directly,
// so we have one place to attach interceptors (e.g. Authorization header,
// 401-driven token refresh) in phase 3.2.
export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_URL,
  headers: {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  },
})
