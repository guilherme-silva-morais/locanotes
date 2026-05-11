<script setup lang="ts">
import { useI18n } from 'vue-i18n'
import { useLocale } from '@/composables/useLocale'
import type { AppLocale } from '@/i18n'

const { t } = useI18n()
const { current, setLocale, options } = useLocale()

function onChange(event: Event) {
  const target = event.target as HTMLSelectElement
  setLocale(target.value as AppLocale)
}
</script>

<template>
  <label class="language-switcher">
    <span class="sr-only">{{ t('common.language') }}</span>
    <select :value="current" data-testid="language-switcher" @change="onChange">
      <option v-for="opt in options" :key="opt.code" :value="opt.code">
        {{ opt.label }}
      </option>
    </select>
  </label>
</template>

<style scoped>
.language-switcher select {
  padding: 0.3rem 0.5rem;
  border: 1px solid #555;
  background: transparent;
  color: inherit;
  border-radius: 4px;
  font-size: 0.9rem;
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
