import { Controller } from "@hotwired/stimulus"

// Submits the 2FA form automatically once a complete 6-digit code is entered,
// so the user isn't required to click "Verify". Backup codes are longer and
// non-numeric, so they fall through to the manual submit button.
export default class extends Controller {
  submit(event) {
    if (/^\d{6}$/.test(event.target.value)) {
      this.element.requestSubmit()
    }
  }
}
