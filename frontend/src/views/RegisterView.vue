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
    <h1>{{ t('auth.register.title') }}</h1>

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

      <button data-testid="submit" type="submit" :disabled="!canSubmit">
        {{ loading ? t('auth.register.submitting') : t('auth.register.submit') }}
      </button>

      <p class="link-row">
        {{ t('auth.register.have_account') }}
        <RouterLink to="/login">{{ t('auth.register.login_link') }}</RouterLink>
      </p>
    </form>
  </main>
</template>

<style scoped>
.auth-view {
  max-width: 22rem;
  margin: 4rem auto;
  padding: 0 1rem;
}

.auth-form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

label {
  font-size: 0.9rem;
  font-weight: 500;
}

input {
  padding: 0.5rem 0.65rem;
  border: 1px solid #ccc;
  border-radius: 4px;
  font-size: 1rem;
}

button {
  padding: 0.6rem;
  border: 0;
  background: #2d6cdf;
  color: white;
  border-radius: 4px;
  font-size: 1rem;
  cursor: pointer;
}

button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.error {
  color: #b00020;
  font-size: 0.85rem;
  margin: 0.1rem 0 0;
}

.link-row {
  text-align: center;
  font-size: 0.9rem;
  margin: 0;
}
</style>
