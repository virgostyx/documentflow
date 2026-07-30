import { Controller } from "@hotwired/stimulus"

// Auto-triggers the "Done editing" link when Collabora Online reports the
// document was closed inside its iframe, so releasing the checkout doesn't
// depend on the user remembering to click back out. The link itself remains
// a manual fallback since exact postMessage payloads can vary by Collabora
// version and can't be verified against a live instance in this environment.
export default class extends Controller {
  static targets = ["doneLink"]
  static values = { origin: String }

  connect() {
    this.onMessage = this.onMessage.bind(this)
    window.addEventListener("message", this.onMessage)
  }

  disconnect() {
    window.removeEventListener("message", this.onMessage)
  }

  onMessage(event) {
    if (this.hasOriginValue && event.origin !== this.originValue) return

    let data = event.data
    if (typeof data === "string") {
      try {
        data = JSON.parse(data)
      } catch {
        return
      }
    }

    if (data && (data.MessageId === "UI_Close" || data.MessageId === "close")) {
      this.doneLinkTarget.click()
    }
  }
}
