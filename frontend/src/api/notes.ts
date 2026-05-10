import { apiClient } from './client'
import type { Note, Paginated } from '@/types/api'

export interface ListParams {
  cursor?: string | null
  limit?: number
}

export interface NoteInput {
  title: string
  content?: string
}

export const notesApi = {
  list: (params: ListParams = {}) =>
    apiClient.get<Paginated<Note>>('/notes', { params }).then((r) => r.data),

  show: (id: number) => apiClient.get<Note>(`/notes/${id}`).then((r) => r.data),

  create: (input: NoteInput) => apiClient.post<Note>('/notes', input).then((r) => r.data),

  update: (id: number, input: Partial<NoteInput>) =>
    apiClient.patch<Note>(`/notes/${id}`, input).then((r) => r.data),

  destroy: (id: number) => apiClient.delete<void>(`/notes/${id}`).then((r) => r.data),
}
