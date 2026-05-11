<script setup lang="ts">
import { RouterView } from 'vue-router'
import LanguageSwitcher from '@/components/LanguageSwitcher.vue'
</script>

<template>
  <header class="app-header">
    <LanguageSwitcher />
  </header>
  <RouterView />
</template>

<style scoped>
.app-header {
  display: flex;
  justify-content: flex-end;
  padding: 0.75rem 1rem;
}
</style>
