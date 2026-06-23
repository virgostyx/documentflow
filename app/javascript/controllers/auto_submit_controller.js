import { Controller } from "@hotwired/stimulus"

// Submits the form as soon as a file is selected, so no explicit upload button is needed.
// Shows the shared loading overlay while the upload is in flight.
export default class extends Controller {
  submit(event) {
    if (event.target.files.length === 0) return

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
