<script setup lang="ts">
import { RouterLink, RouterView, useRouter } from 'vue-router'
import { useI18n } from 'vue-i18n'
import { useAuthStore } from '@/stores/auth'
import LanguageSwitcher from '@/components/LanguageSwitcher.vue'
import ThemeSwitcher from '@/components/ThemeSwitcher.vue'

const { t } = useI18n()
const auth = useAuthStore()
const router = useRouter()

async function logout() {
  await auth.logout()
  await router.push('/login')
}
</script>

<template>
  <header class="app-header">
    <div class="app-header-inner">
      <RouterLink to="/" class="brand">locanotes</RouterLink>
      <nav class="app-header-actions">
        <ThemeSwitcher />
        <LanguageSwitcher />
        <span
          v-if="auth.user"
          class="user-email"
          data-testid="user-email"
          :title="auth.user.email_address"
        >
          {{ auth.user.email_address }}
        </span>
        <button
          v-if="auth.isAuthenticated"
          data-testid="logout"
          type="button"
          class="logout-button"
          @click="logout"
        >
          {{ t('auth.logout') }}
        </button>
      </nav>
    </div>
  </header>
  <RouterView />
</template>

<style scoped>
.app-header {
  position: sticky;
  top: 0;
  z-index: 10;
  background: var(--color-surface);
  border-bottom: 1px solid var(--color-border);
  box-shadow: var(--shadow-sm);
}

.app-header-inner {
  max-width: 56rem;
  margin: 0 auto;
  padding: var(--space-3) var(--space-4);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-4);
  min-height: var(--header-height);
}

.brand {
  font-size: 1.15rem;
  font-weight: 700;
  letter-spacing: -0.01em;
  color: var(--color-text);
  white-space: nowrap;
}

.brand:hover {
  text-decoration: none;
  color: var(--color-primary);
}

.app-header-actions {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  flex-wrap: wrap;
  justify-content: flex-end;
}

.user-email {
  font-size: var(--font-size-sm);
  color: var(--color-text-muted);
  max-width: 14rem;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.logout-button {
  background: transparent;
  border: 1px solid var(--color-border-strong);
  color: var(--color-text);
  padding: var(--space-1) var(--space-3);
  border-radius: var(--radius-md);
  font-size: var(--font-size-sm);
  transition:
    background var(--transition-fast),
    border-color var(--transition-fast);
}

.logout-button:hover {
  background: var(--color-bg);
  border-color: var(--color-primary);
  color: var(--color-primary);
}

@media (max-width: 32rem) {
  .user-email {
    display: none;
  }
}
</style>
