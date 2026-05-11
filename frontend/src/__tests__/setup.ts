import { afterAll, afterEach, beforeAll, beforeEach } from 'vitest'
import { setupServer } from 'msw/node'
import { setActivePinia, createPinia } from 'pinia'
import { i18n } from '@/i18n'
import { apiClient } from '@/api/client'

// In jsdom axios picks the XHR adapter by default, which routes through MSW's
// XMLHttpRequest interceptor. That interceptor dispatches response events as
// ProgressEvent; if a request settles after a parallel spec's jsdom env was
// torn down, the constructor lookup fails with a flaky unhandled rejection.
// Forcing the `fetch` adapter avoids the XHR codepath entirely — MSW still
// intercepts via its fetch handler, which doesn't construct ProgressEvent.
apiClient.defaults.adapter = 'fetch'

// One shared MSW server across the whole spec suite. Individual specs add
// handlers via `mswServer.use(...)` which are reset after each test.
export const mswServer = setupServer()

beforeAll(() => mswServer.listen({ onUnhandledRequest: 'error' }))

beforeEach(() => {
  // Fresh Pinia instance per test so stores don't bleed state between specs.
  setActivePinia(createPinia())
  // Fresh localStorage too — auth store reads from it at construction.
  localStorage.clear()
  // Pin the locale so spec assertions against translated text are stable.
  // (jsdom's navigator.language defaults to en-US, which would otherwise flip
  // the app to English and break specs that assert pt-BR strings.)
  i18n.global.locale.value = 'pt-BR'
})

afterEach(() => {
  mswServer.resetHandlers()
})

afterAll(() => mswServer.close())
