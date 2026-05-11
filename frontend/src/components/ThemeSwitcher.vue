<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { useTheme, type ThemePref } from '@/composables/useTheme'

const { t } = useI18n()
const { theme, setTheme } = useTheme()

function onChange(event: Event) {
  setTheme((event.target as HTMLSelectElement).value as ThemePref)
}
</script>

<template>
  <label class="theme-switcher">
    <span class="sr-only">{{ t('common.theme') }}</span>
    <select :value="theme" data-testid="theme-switcher" @change="onChange">
      <option value="system">{{ t('common.theme_system') }}</option>
      <option value="light">{{ t('common.theme_light') }}</option>
      <option value="dark">{{ t('common.theme_dark') }}</option>
    </select>
  </label>
</template>

<style scoped>
.theme-switcher select {
  padding: var(--space-1) var(--space-3);
  border: 1px solid var(--color-border-strong);
  background: var(--color-surface);
  color: inherit;
  border-radius: var(--radius-md);
  font-size: var(--font-size-sm);
  transition: border-color var(--transition-fast);
  cursor: pointer;
}

.theme-switcher select:hover {
  border-color: var(--color-primary);
}

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}
</style>
