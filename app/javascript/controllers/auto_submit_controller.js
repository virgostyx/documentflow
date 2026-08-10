import { Controller } from "@hotwired/stimulus"

// Submits the form as soon as its input changes, so no explicit submit button is needed.
// Shows the shared loading overlay while the request is in flight. For file inputs, skips
// submitting if the selection was cleared rather than changed.
export default class extends Controller {
  submit(event) {
    if (event.target.files && event.target.files.length === 0) return

    this._showOverlay()
    this.element.addEventListener("turbo:submit-end", () => this._hideOverlay(), { once: true })
    this.element.requestSubmit()
  }

  _showOverlay() {
    document.getElementById("upload-loading-overlay")?.classList.remove("hidden")
  }

  _hideOverlay() {
    document.getElementById("upload-loading-overlay")?.classList.add("hidden")
  }
}
