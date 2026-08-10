import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "editorFrame", "fullscreenExpandIcon", "fullscreenCollapseIcon", "previewLoader", "previewFrame"]

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
    this.currentFrame = event.target
    this.applyWidth(event.target)
  }

  // Most modal content (forms, confirmations) is comfortable at the default
  // width. A few (the WOPI online editor) opt into a wider dialog by
  // including a `[data-modal-wide]` marker in their content.
  applyWidth(frame) {
    const wide = frame.querySelector("[data-modal-wide]") !== null
    this.dialogTarget.classList.toggle("max-w-4xl", !wide)
    this.dialogTarget.classList.toggle("max-w-[80.64rem]", wide)
  }

  show() {
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  hidePreviewLoader() {
    if (this.hasPreviewLoaderTarget) this.previewLoaderTarget.classList.add("hidden")
  }

  // The iframe can finish loading before this controller connects and binds
  // its `load` action — e.g. a small already-PDF file served instantly,
  // versus the deferred module script that registers Stimulus controllers.
  // Catch that race by checking whether it's already done as soon as the
  // target is discovered.
  previewFrameTargetConnected(frame) {
    if (frame.contentDocument?.readyState === "complete") this.hidePreviewLoader()
  }

  closeBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  toggleFullscreen() {
    if (this.dialogTarget.classList.contains("h-screen")) {
      this.exitFullscreen()
    } else {
      this.enterFullscreen()
    }
  }

  enterFullscreen() {
    this.dialogTarget.classList.remove("max-w-4xl", "max-w-[80.64rem]", "max-h-[90vh]", "rounded-lg", "m-auto")
    this.dialogTarget.classList.add("max-w-none", "max-h-none", "h-screen", "rounded-none", "m-0")
    if (this.hasEditorFrameTarget) this.editorFrameTarget.classList.replace("h-[80vh]", "h-[calc(100vh-8rem)]")
    this.setFullscreenIcon(true)
  }

  // Wired to the dialog's native `close` event so every close path (backdrop
  // click, Escape, or `.close()`) resets fullscreen for the next open — not
  // just the explicit toggle. Guard against unrelated `close` events since
  // that event doesn't bubble but this action is bound directly on the
  // dialog element itself.
  exitFullscreen(event) {
    if (event && event.target !== this.dialogTarget) return

    this.dialogTarget.classList.remove("max-w-none", "max-h-none", "h-screen", "rounded-none", "m-0")
    this.dialogTarget.classList.add("max-h-[90vh]", "rounded-lg", "m-auto")
    if (this.currentFrame) this.applyWidth(this.currentFrame)
    if (this.hasEditorFrameTarget) this.editorFrameTarget.classList.replace("h-[calc(100vh-8rem)]", "h-[80vh]")
    this.setFullscreenIcon(false)
  }

  setFullscreenIcon(fullscreen) {
    if (this.hasFullscreenExpandIconTarget) this.fullscreenExpandIconTarget.classList.toggle("hidden", fullscreen)
    if (this.hasFullscreenCollapseIconTarget) this.fullscreenCollapseIconTarget.classList.toggle("hidden", !fullscreen)
  }
}
