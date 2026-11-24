import { reactive } from 'vue'

// In-app replacement for window.confirm(), which some WebViews block or show
// as a bare system dialog. ConfirmHost (mounted once in App.vue) renders it.
interface ConfirmOptions {
  title: string
  body?: string
  confirmLabel?: string
  cancelLabel?: string
  destructive?: boolean
}

export const confirmState = reactive({
  open: false,
  options: { title: '' } as ConfirmOptions,
  resolve: null as ((ok: boolean) => void) | null,
})

export function confirmAction(options: ConfirmOptions) {
  confirmState.resolve?.(false)
  confirmState.options = options
  confirmState.open = true
  return new Promise<boolean>((resolve) => {
    confirmState.resolve = resolve
  })
}

export function settleConfirm(ok: boolean) {
  confirmState.resolve?.(ok)
  confirmState.resolve = null
  confirmState.open = false
}
