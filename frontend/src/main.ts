import './assets/main.css'

import { createApp } from 'vue'
import { createPinia } from 'pinia'

import App from './App.vue'
import router from './router'
import { i18n } from './i18n'
import { installInterceptors } from './api/install-interceptors'

const app = createApp(App)

app.use(createPinia())
app.use(i18n)
// Interceptors must be installed after Pinia (they read from the auth store)
// and before the router (route guards may already hit the API).
installInterceptors()
app.use(router)

app.mount('#app')
