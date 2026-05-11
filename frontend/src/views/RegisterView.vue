<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter, RouterLink } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { isAxiosError } from 'axios'
import { useAuthStore } from '@/stores/auth'
import { isValidationError, type ApiErrorBody } from '@/types/api'

const { t } = useI18n()
const auth = useAuthStore()
const router = useRouter()

const email = ref('')
const password = ref('')
const passwordConfirmation = ref('')

const loading = ref(false)
const formError = ref<string | null>(null)
const fieldErrors = ref<Record<string, string[]>>({})

const canSubmit = computed(
  () =>
    email.value.length > 0 &&
    password.value.length > 0 &&
    passwordConfirmation.value.length > 0 &&
    !loading.value,
)

async function onSubmit() {
  if (!canSubmit.value) return

  loading.value = true
  formError.value = null
  fieldErrors.value = {}

  try {
    await auth.register({
      email_address: email.value,
      password: password.value,
      password_confirmation: passwordConfirmation.value,
    })
    await router.push('/notes')
  } catch (err) {
    handleError(err)
  } finally {
    loading.value = false
  }
}

function handleError(err: unknown) {
  if (isAxiosError(err)) {
    const status = err.response?.status
    const data = err.response?.data as ApiErrorBody | undefined

    if (data && isValidationError(data)) {
      fieldErrors.value = data.errors
      return
    }
    if (data && 'error' in data) {
      formError.value = data.error
      return
    }
    if (status === 429) {
      formError.value = t('auth.errors.rate_limited')
      return
    }
  }
  formError.value = t('auth.errors.network')
}
</script>

<template>
  <main class="auth-view">
    <section class="auth-card">
      <h1 class="auth-title">{{ t('auth.register.title') }}</h1>

      <form class="auth-form" novalidate @submit.prevent="onSubmit">
        <div class="field">
          <label for="register-email">{{ t('auth.register.email_label') }}</label>
          <input
            id="register-email"
            v-model="email"
            data-testid="email"
            type="email"
            autocomplete="email"
            autofocus
            required
            maxlength="200"
          />
          <p v-if="fieldErrors.email_address" data-testid="email-error" class="error">
            {{ fieldErrors.email_address.join(', ') }}
          </p>
        </div>

        <div class="field">
          <label for="register-password">{{ t('auth.register.password_label') }}</label>
          <input
            id="register-password"
            v-model="password"
            data-testid="password"
            type="password"
            autocomplete="new-password"
            required
            maxlength="72"
          />
          <p v-if="fieldErrors.password" data-testid="password-error" class="error">
            {{ fieldErrors.password.join(', ') }}
          </p>
        </div>

        <div class="field">
          <label for="register-password-confirmation">
            {{ t('auth.register.password_confirmation_label') }}
          </label>
          <input
            id="register-password-confirmation"
            v-model="passwordConfirmation"
            data-testid="password-confirmation"
            type="password"
            autocomplete="new-password"
            required
            maxlength="72"
          />
          <p
            v-if="fieldErrors.password_confirmation"
            data-testid="password-confirmation-error"
            class="error"
          >
            {{ fieldErrors.password_confirmation.join(', ') }}
          </p>
        </div>

        <p v-if="formError" data-testid="form-error" class="error" role="alert">
          {{ formError }}
        </p>

        <button data-testid="submit" type="submit" class="primary-button" :disabled="!canSubmit">
          {{ loading ? t('auth.register.submitting') : t('auth.register.submit') }}
        </button>

        <p class="link-row">
          {{ t('auth.register.have_account') }}
          <RouterLink to="/login">{{ t('auth.register.login_link') }}</RouterLink>
        </p>
      </form>
    </section>
  </main>
</template>

<style scoped>
.auth-view {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--space-10) var(--space-4);
  flex: 1;
}

.auth-card {
  width: 100%;
  max-width: 22rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  padding: var(--space-6);
  box-shadow: var(--shadow-md);
}

.auth-title {
  font-size: 1.35rem;
  font-weight: 600;
  margin: 0 0 var(--space-5);
}

.auth-form {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
}

.field {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}

label {
  font-size: var(--font-size-sm);
  font-weight: 500;
  color: var(--color-text-muted);
}

input {
  padding: var(--space-2) var(--space-3);
  border: 1px solid var(--color-border-strong);
  background: var(--color-input-bg);
  border-radius: var(--radius-md);
  transition: border-color var(--transition-fast);
}

input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px rgba(45, 108, 223, 0.15);
}

.primary-button {
  margin-top: var(--space-2);
  padding: var(--space-3);
  border: 0;
  background: var(--color-primary);
  color: var(--color-primary-contrast);
  border-radius: var(--radius-md);
  font-weight: 600;
  transition: background var(--transition-fast);
}

.primary-button:hover:not(:disabled) {
  background: var(--color-primary-hover);
}

.primary-button:disabled {
  opacity: 0.55;
}

.error {
  color: var(--color-danger);
  font-size: var(--font-size-sm);
  margin: var(--space-1) 0 0;
}

.link-row {
  text-align: center;
  font-size: var(--font-size-sm);
  margin: 0;
  color: var(--color-text-muted);
}
</style>
