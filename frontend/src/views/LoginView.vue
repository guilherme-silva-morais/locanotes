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
    <section class="auth-card">
      <h1 class="auth-title">{{ t('auth.login.title') }}</h1>

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

        <button data-testid="submit" type="submit" class="primary-button" :disabled="!canSubmit">
          {{ loading ? t('auth.login.submitting') : t('auth.login.submit') }}
        </button>

        <p class="link-row">
          {{ t('auth.login.no_account') }}
          <RouterLink to="/register">{{ t('auth.login.register_link') }}</RouterLink>
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
  margin: 0;
}

.link-row {
  text-align: center;
  font-size: var(--font-size-sm);
  margin: 0;
  color: var(--color-text-muted);
}
</style>
