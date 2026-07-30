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
    this.applyWidth(event.target)
  }

  // Most modal content (forms, confirmations) is comfortable at the default
  // width. A few (the WOPI online editor) opt into a wider dialog by
  // including a `[data-modal-wide]` marker in their content.
  applyWidth(frame) {
    const wide = frame.querySelector("[data-modal-wide]") !== null
    this.dialogTarget.classList.toggle("max-w-4xl", !wide)
    this.dialogTarget.classList.toggle("max-w-[67.2rem]", wide)
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
