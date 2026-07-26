import { Controller } from "@hotwired/stimulus"

// The controller's element is a native <details>, so opening/closing on
// summary click is handled by the browser — never racy, unlike a Stimulus
// click action that might not be bound yet right after a Turbo Drive page
// render. This controller only adds the (non-essential) convenience of
// closing the menu when clicking outside of it.
export default class extends Controller {
  connect() {
    this.outsideClick = this.outsideClick.bind(this)
    document.addEventListener("click", this.outsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClick)
  }

  outsideClick(event) {
    if (this.element.open && !this.element.contains(event.target)) this.element.open = false
  }
}
