import { mount } from '@vue/test-utils'
import { getActivePinia } from 'pinia'
import { createRouter, createMemoryHistory, type Router } from 'vue-router'
import { routes, authGuard } from '@/router'
import { i18n } from '@/i18n'
import type { Component, DefineComponent } from 'vue'

// Build a fresh, memory-history router for each test so navigation under test
// doesn't bleed across specs. Re-attaches the same authGuard used in production.
export function buildRouter(): Router {
  const router = createRouter({
    history: createMemoryHistory(),
    routes,
  })
  router.beforeEach(authGuard)
  return router
}

type MountOpts = Parameters<typeof mount>[1]

export async function mountView(
  component: Component,
  opts: MountOpts = {},
  initialPath = '/login',
) {
  const router = buildRouter()
  await router.push(initialPath)
  await router.isReady()

  const pinia = getActivePinia()
  if (!pinia) throw new Error('Pinia must be active — check spec/__tests__/setup.ts')

  // Casting component to `DefineComponent` so mount's heavy generic inference
  // collapses to a concrete shape; the wrapper returned remains usable by tests.
  const wrapper = mount(component as DefineComponent, {
    ...opts,
    global: {
      ...opts?.global,
      plugins: [pinia, router, i18n],
    },
  })

  return { wrapper, router }
}
