<script setup lang="ts">
import { useI18n } from 'vue-i18n'

const { t } = useI18n()
</script>

<template>
  <main class="notes-view">
    <h1>{{ t('notes.title') }}</h1>
    <p>{{ t('notes.placeholder') }}</p>
  </main>
</template>
