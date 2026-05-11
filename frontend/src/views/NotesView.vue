<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import { notesApi } from '@/api/notes'
import type { Note } from '@/types/api'

const { t } = useI18n()
const auth = useAuthStore()
const router = useRouter()

const notes = ref<Note[]>([])
const nextCursor = ref<string | null>(null)
const hasMore = ref(false)
const loading = ref(false)
const error = ref<string | null>(null)

async function fetchPage(cursor: string | null = null) {
  loading.value = true
  error.value = null
  try {
    const result = await notesApi.list({ cursor, limit: 20 })
    if (cursor === null) {
      notes.value = result.data
    } else {
      notes.value.push(...result.data)
    }
    nextCursor.value = result.next_cursor
    hasMore.value = result.has_more
  } catch {
    error.value = t('notes.errors.load')
  } finally {
    loading.value = false
  }
}

async function loadMore() {
  if (!hasMore.value || loading.value) return
  await fetchPage(nextCursor.value)
}

async function logout() {
  await auth.logout()
  await router.push('/login')
}

onMounted(() => fetchPage())
</script>

<template>
  <main class="notes-view">
    <header class="notes-header">
      <span class="user-email">{{ auth.user?.email_address }}</span>
      <button data-testid="logout" type="button" class="link-button" @click="logout">
        {{ t('auth.logout') }}
      </button>
    </header>

    <h1>{{ t('notes.title') }}</h1>

    <p v-if="loading && notes.length === 0" data-testid="loading">
      {{ t('notes.loading') }}
    </p>

    <p v-else-if="error" data-testid="load-error" class="error" role="alert">
      {{ error }}
    </p>

    <p v-else-if="notes.length === 0" data-testid="empty" class="empty">
      {{ t('notes.empty') }}
    </p>

    <ul v-else class="notes-list" data-testid="notes-list">
      <li v-for="note in notes" :key="note.id" class="note-item" data-testid="note-item">
        <h3>{{ note.title }}</h3>
        <p v-if="note.content">{{ note.content }}</p>
      </li>
    </ul>

    <button
      v-if="hasMore"
      data-testid="load-more"
      type="button"
      class="load-more"
      :disabled="loading"
      @click="loadMore"
    >
      {{ loading ? t('notes.loading') : t('notes.load_more') }}
    </button>
  </main>
</template>

<style scoped>
.notes-view {
  max-width: 42rem;
  margin: 2rem auto;
  padding: 0 1rem;
}

.notes-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  font-size: 0.9rem;
}

.user-email {
  opacity: 0.75;
}

.link-button {
  background: none;
  border: 0;
  color: #4a8cff;
  font: inherit;
  cursor: pointer;
  padding: 0;
  text-decoration: underline;
}

.notes-list {
  list-style: none;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.note-item {
  border: 1px solid #2a2a2a;
  border-radius: 6px;
  padding: 0.75rem 1rem;
}

.note-item h3 {
  margin: 0 0 0.25rem;
  font-size: 1rem;
}

.note-item p {
  margin: 0;
  font-size: 0.9rem;
  opacity: 0.85;
  white-space: pre-wrap;
}

.empty {
  opacity: 0.65;
  text-align: center;
  padding: 2rem 0;
}

.error {
  color: #ff6b6b;
}

.load-more {
  margin-top: 1rem;
  width: 100%;
  padding: 0.6rem;
  border: 1px solid #444;
  background: transparent;
  color: inherit;
  border-radius: 4px;
  cursor: pointer;
}

.load-more:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
