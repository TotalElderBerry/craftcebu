import { createPinia } from 'pinia'
import { createApp } from 'vue'
import App from './App.vue'
import { inApp, installAppHandlers } from './lib/app/bridge'
import router from './router'
import { useCartStore } from './stores/cart'
import 'vue-sonner/style.css'
import './style.css'

const app = createApp(App).use(createPinia()).use(router)

// Before mounting, so the app's session reply can reach the first route guard.
if (inApp) {
  installAppHandlers({
    navigate: path => router.push(path),
    reloadCart: () => useCartStore().reload(),
  })
}

app.mount('#app')
