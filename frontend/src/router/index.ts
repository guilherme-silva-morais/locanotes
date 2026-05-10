import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

import LoginView from '@/views/LoginView.vue'
import RegisterView from '@/views/RegisterView.vue'
import NotesView from '@/views/NotesView.vue'

// `routes` is exported (without the router instance) so specs can build a
// fresh router on top of `createMemoryHistory` without colliding with the
// app's real history.
export const routes: RouteRecordRaw[] = [
  { path: '/', redirect: { name: 'notes' } },
  {
    path: '/login',
    name: 'login',
    component: LoginView,
    meta: { guestOnly: true },
  },
  {
    path: '/register',
    name: 'register',
    component: RegisterView,
    meta: { guestOnly: true },
  },
  {
    path: '/notes',
    name: 'notes',
    component: NotesView,
    meta: { requiresAuth: true },
  },
  // Catch-all: unknown paths go through normal guards (will hit /notes auth check).
  { path: '/:pathMatch(.*)*', redirect: { name: 'notes' } },
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
})

// Exported so spec routers can re-attach the same guard without re-implementing.
export function authGuard(to: import('vue-router').RouteLocationNormalized) {
  const auth = useAuthStore()

  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }

  if (to.meta.guestOnly && auth.isAuthenticated) {
    return { name: 'notes' }
  }

  return true
}

router.beforeEach(authGuard)

export default router
