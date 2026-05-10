import { afterAll, afterEach, beforeAll, beforeEach } from 'vitest'
import { setupServer } from 'msw/node'
import { setActivePinia, createPinia } from 'pinia'

// One shared MSW server across the whole spec suite. Individual specs add
// handlers via `mswServer.use(...)` which are reset after each test.
export const mswServer = setupServer()

beforeAll(() => mswServer.listen({ onUnhandledRequest: 'error' }))

beforeEach(() => {
  // Fresh Pinia instance per test so stores don't bleed state between specs.
  setActivePinia(createPinia())
  // Fresh localStorage too — auth store reads from it at construction.
  localStorage.clear()
})

afterEach(() => {
  mswServer.resetHandlers()
})

afterAll(() => mswServer.close())
