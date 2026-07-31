import { Controller } from "@hotwired/stimulus"

// Submits the 2FA form automatically once a complete 6-digit code is entered,
// so the user isn't required to click "Verify". Backup codes are longer and
// non-numeric, so they fall through to the manual submit button. Also swaps
// the submit button's label for a spinner while the request is in flight.
export default class extends Controller {
  static targets = ["label", "spinner", "submit"]

  connect() {
    this.onSubmitStart = this.onSubmitStart.bind(this)
    this.onSubmitEnd = this.onSubmitEnd.bind(this)
    this.element.addEventListener("turbo:submit-start", this.onSubmitStart)
    this.element.addEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this.onSubmitStart)
    this.element.removeEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  submit(event) {
    if (/^\d{6}$/.test(event.target.value)) {
      this.element.requestSubmit()
    }
  }

  onSubmitStart() {
    this.submitTarget.disabled = true
    this.labelTarget.classList.add("hidden")
    this.spinnerTarget.classList.remove("hidden")
    this.spinnerTarget.classList.add("inline-flex")
  }

  onSubmitEnd(event) {
    if (event.detail.success) return

    this.submitTarget.disabled = false
    this.labelTarget.classList.remove("hidden")
    this.spinnerTarget.classList.add("hidden")
    this.spinnerTarget.classList.remove("inline-flex")
  }
}
