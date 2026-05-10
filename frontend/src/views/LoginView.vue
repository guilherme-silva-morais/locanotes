<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter, useRoute, RouterLink } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { isAxiosError } from 'axios'
import { useAuthStore } from '@/stores/auth'

const { t } = useI18n()
const auth = useAuthStore()
const router = useRouter()
const route = useRoute()

const email = ref('')
const password = ref('')
const loading = ref(false)
const formError = ref<string | null>(null)

const canSubmit = computed(
  () => email.value.length > 0 && password.value.length > 0 && !loading.value,
)

async function onSubmit() {
  if (!canSubmit.value) return

  loading.value = true
  formError.value = null

  try {
    await auth.login({ email_address: email.value, password: password.value })
    const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : '/notes'
    await router.push(redirect)
  } catch (err) {
    formError.value = extractMessage(err)
  } finally {
    loading.value = false
  }
}

function extractMessage(err: unknown): string {
  if (isAxiosError(err)) {
    const data = err.response?.data as { error?: string } | undefined
    if (data?.error) return data.error
    if (err.response?.status === 429) return t('auth.errors.rate_limited')
  }
  return t('auth.errors.network')
}
</script>

<template>
  <main class="auth-view">
    <h1>{{ t('auth.login.title') }}</h1>

    <form class="auth-form" novalidate @submit.prevent="onSubmit">
      <div class="field">
        <label for="login-email">{{ t('auth.login.email_label') }}</label>
        <input
          id="login-email"
          v-model="email"
          data-testid="email"
          type="email"
          autocomplete="email"
          autofocus
          required
          maxlength="200"
        />
      </div>

      <div class="field">
        <label for="login-password">{{ t('auth.login.password_label') }}</label>
        <input
          id="login-password"
          v-model="password"
          data-testid="password"
          type="password"
          autocomplete="current-password"
          required
          maxlength="72"
        />
      </div>

      <p v-if="formError" data-testid="form-error" class="error" role="alert">
        {{ formError }}
      </p>

      <button data-testid="submit" type="submit" :disabled="!canSubmit">
        {{ loading ? t('auth.login.submitting') : t('auth.login.submit') }}
      </button>

      <p class="link-row">
        {{ t('auth.login.no_account') }}
        <RouterLink to="/register">{{ t('auth.login.register_link') }}</RouterLink>
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
  font-size: 0.9rem;
  margin: 0;
}

.link-row {
  text-align: center;
  font-size: 0.9rem;
  margin: 0;
}
</style>
