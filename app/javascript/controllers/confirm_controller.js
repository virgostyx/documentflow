import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message", "confirmButton", "container"]

  confirmAction(event) {
    if (!this.element.open) return
    if (event) event.preventDefault()

    this.hide()

    if (window.confirmResolver) {
      window.confirmResolver(true)
      window.confirmResolver = null
    }
  }

  cancel(event) {
    if (!this.element.open) return
    if (event) event.preventDefault()

    this.hide()

    if (window.confirmResolver) {
      window.confirmResolver(false)
      window.confirmResolver = null
    }
  }

  // Clicking the dialog's ::backdrop dispatches a click with the dialog
  // itself as the target (there's no separate backdrop element to bind to).
  closeBackdrop(event) {
    if (event.target === this.element) this.cancel(event)
  }

  show() {
    if (!this.element.open) this.element.showModal()

    setTimeout(() => {
      this.confirmButtonTarget.focus()
    }, 100)
  }

  hide() {
    if (this.element.open) this.element.close()
  }
}
