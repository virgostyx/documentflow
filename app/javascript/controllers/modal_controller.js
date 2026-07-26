import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  // Opens immediately on click, for the common case. `frameLoaded` is a
  // fallback for when this click action hasn't been (re)bound yet by the
  // time the click happens — e.g. right after a full-page Turbo Drive render
  // replaces `<body>` and Stimulus hasn't finished reconnecting. Turbo's own
  // frame fetch is framework-level and unaffected by that reconnection, so
  // once it resolves we can rely on it to open the dialog reliably.
  open() {
    this.show()
  }

  frameLoaded(event) {
    if (event.target.src) this.show()
  }

  show() {
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  closeBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
