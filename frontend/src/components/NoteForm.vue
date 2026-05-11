<script setup lang="ts">
import { ref, computed } from 'vue'
import { useI18n } from 'vue-i18n'
import { isAxiosError } from 'axios'
import { notesApi } from '@/api/notes'
import { isValidationError, type ApiErrorBody, type Note } from '@/types/api'

const TITLE_MAX = 120
const CONTENT_MAX = 10_000

const emit = defineEmits<{
  'note-created': [note: Note]
}>()

const { t } = useI18n()

const title = ref('')
const content = ref('')
const loading = ref(false)
const titleTouched = ref(false)
const fieldErrors = ref<Record<string, string[]>>({})
const formError = ref<string | null>(null)

const titleLength = computed(() => title.value.length)
const contentLength = computed(() => content.value.length)

const titleClientError = computed(() => {
  if (!titleTouched.value) return null
  if (title.value.trim().length === 0) return t('notes.form.title_required')
  return null
})

const canSubmit = computed(
  () =>
    title.value.trim().length > 0 &&
    titleLength.value <= TITLE_MAX &&
    contentLength.value <= CONTENT_MAX &&
    !loading.value,
)

async function onSubmit() {
  titleTouched.value = true
  if (!canSubmit.value) return

  loading.value = true
  fieldErrors.value = {}
  formError.value = null

  try {
    const note = await notesApi.create({ title: title.value, content: content.value })
    emit('note-created', note)
    title.value = ''
    content.value = ''
    titleTouched.value = false
  } catch (err) {
    handleError(err)
  } finally {
    loading.value = false
  }
}

function handleError(err: unknown) {
  if (isAxiosError(err)) {
    const data = err.response?.data as ApiErrorBody | undefined
    if (data && isValidationError(data)) {
      fieldErrors.value = data.errors
      return
    }
    if (data && 'error' in data) {
      formError.value = data.error
      return
    }
  }
  formError.value = t('auth.errors.network')
}
</script>

<template>
  <section class="card">
    <h2 class="section-heading">{{ t('notes.form.heading') }}</h2>

    <form class="note-form" novalidate @submit.prevent="onSubmit">
      <div class="field-row">
        <label for="note-title">{{ t('notes.form.title_label') }}</label>
        <div class="field-control">
          <input
            id="note-title"
            v-model="title"
            data-testid="title"
            type="text"
            :maxlength="TITLE_MAX"
            :placeholder="t('notes.form.title_placeholder')"
            required
            @blur="titleTouched = true"
          />
          <div class="field-meta">
            <p
              v-if="titleClientError || fieldErrors.title"
              data-testid="title-error"
              class="error"
            >
              {{ titleClientError ?? fieldErrors.title?.join(', ') }}
            </p>
            <span data-testid="title-counter" class="counter">
              {{ titleLength }} / {{ TITLE_MAX }}
            </span>
          </div>
        </div>
      </div>

      <div class="field-row">
        <label for="note-content">{{ t('notes.form.content_label') }}</label>
        <div class="field-control">
          <textarea
            id="note-content"
            v-model="content"
            data-testid="content"
            :maxlength="CONTENT_MAX"
            :placeholder="t('notes.form.content_placeholder')"
            rows="4"
          />
          <div class="field-meta">
            <p v-if="fieldErrors.content" data-testid="content-error" class="error">
              {{ fieldErrors.content.join(', ') }}
            </p>
            <span data-testid="content-counter" class="counter">
              {{ contentLength }} / {{ CONTENT_MAX }}
            </span>
          </div>
        </div>
      </div>

      <p v-if="formError" data-testid="form-error" class="error" role="alert">
        {{ formError }}
      </p>

      <div class="form-actions">
        <button data-testid="submit" type="submit" class="primary-button" :disabled="!canSubmit">
          {{ loading ? t('notes.form.submitting') : t('notes.form.submit') }}
        </button>
      </div>
    </form>
  </section>
</template>

<style scoped>
.card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: var(--space-6);
  box-shadow: var(--shadow-sm);
}

.section-heading {
  font-size: 1.15rem;
  font-weight: 600;
  margin: 0 0 var(--space-5);
  padding-bottom: var(--space-3);
  border-bottom: 1px solid var(--color-border);
}

.note-form {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

.field-row {
  display: grid;
  grid-template-columns: 5.5rem 1fr;
  gap: var(--space-3);
  align-items: start;
}

.field-row label {
  text-align: right;
  padding-top: 0.55rem;
  color: var(--color-text-muted);
  font-size: var(--font-size-sm);
}

.field-control {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
  min-width: 0;
}

input,
textarea {
  padding: var(--space-2) var(--space-3);
  border: 1px solid var(--color-border-strong);
  background: var(--color-input-bg);
  border-radius: var(--radius-md);
  width: 100%;
  resize: vertical;
  transition: border-color var(--transition-fast);
}

input:focus,
textarea:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px rgba(45, 108, 223, 0.15);
}

input::placeholder,
textarea::placeholder {
  color: var(--color-text-muted);
  opacity: 0.7;
}

.field-meta {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: var(--space-2);
  min-height: 1.1rem;
}

.counter {
  font-size: var(--font-size-xs);
  color: var(--color-text-muted);
  font-variant-numeric: tabular-nums;
  margin-left: auto;
}

.error {
  color: var(--color-danger);
  font-size: var(--font-size-sm);
  margin: 0;
}

.form-actions {
  display: flex;
  justify-content: center;
}

.primary-button {
  background: var(--color-primary);
  color: var(--color-primary-contrast);
  border: 0;
  border-radius: var(--radius-md);
  padding: var(--space-2) var(--space-8);
  font-weight: 600;
  transition: background var(--transition-fast);
}

.primary-button:hover:not(:disabled) {
  background: var(--color-primary-hover);
}

.primary-button:disabled {
  opacity: 0.55;
}

@media (max-width: 32rem) {
  .field-row {
    grid-template-columns: 1fr;
  }

  .field-row label {
    text-align: left;
    padding-top: 0;
  }
}
</style>
