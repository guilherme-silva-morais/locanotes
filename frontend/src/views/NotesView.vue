<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useI18n } from 'vue-i18n'
import { notesApi } from '@/api/notes'
import NoteForm from '@/components/NoteForm.vue'
import type { Note } from '@/types/api'

const { t } = useI18n()

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

function onNoteCreated(note: Note) {
  notes.value.unshift(note)
}

onMounted(() => fetchPage())
</script>

<template>
  <main class="notes-view">
    <NoteForm @note-created="onNoteCreated" />

    <section class="card">
      <h2 class="section-heading">{{ t('notes.title') }}</h2>

      <p v-if="loading && notes.length === 0" data-testid="loading" class="muted">
        {{ t('notes.loading') }}
      </p>

      <p v-else-if="error" data-testid="load-error" class="error" role="alert">
        {{ error }}
      </p>

      <p v-else-if="notes.length === 0" data-testid="empty" class="muted empty">
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
    </section>
  </main>
</template>

<style scoped>
.notes-view {
  max-width: 40rem;
  margin: var(--space-8) auto;
  padding: 0 var(--space-4);
  display: flex;
  flex-direction: column;
  gap: var(--space-6);
}

.card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: var(--space-6);
  box-shadow: var(--shadow-sm);
  min-width: 0;
  overflow: hidden;
}

.section-heading {
  font-size: 1.15rem;
  font-weight: 600;
  margin: 0 0 var(--space-5);
  padding-bottom: var(--space-3);
  border-bottom: 1px solid var(--color-border);
}

.muted {
  color: var(--color-text-muted);
}

.empty {
  text-align: center;
  padding: var(--space-6) 0;
}

.error {
  color: var(--color-danger);
}

.notes-list {
  list-style: disc;
  padding-left: var(--space-6);
  margin: 0;
}

.note-item {
  padding: var(--space-3) 0;
  border-bottom: 1px solid var(--color-border);
}

.note-item:last-child {
  border-bottom: 0;
}

.note-item h3 {
  margin: 0;
  font-size: 1rem;
  font-weight: 600;
  /* Break very long words / unbreakable strings so they wrap inside the card. */
  overflow-wrap: anywhere;
  word-break: break-word;
}

.note-item p {
  margin: var(--space-1) 0 0;
  color: var(--color-text-muted);
  font-size: var(--font-size-sm);
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  word-break: break-word;
}

.load-more {
  margin-top: var(--space-5);
  width: 100%;
  padding: var(--space-2);
  border: 1px solid var(--color-border-strong);
  background: var(--color-surface);
  border-radius: var(--radius-md);
  transition:
    background var(--transition-fast),
    border-color var(--transition-fast);
}

.load-more:hover:not(:disabled) {
  background: var(--color-bg);
  border-color: var(--color-primary);
  color: var(--color-primary);
}

.load-more:disabled {
  opacity: 0.55;
}
</style>
