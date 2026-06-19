import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.close = this.close.bind(this)
  }

  open(event) {
    event.preventDefault()
    this.menuTarget.style.top = `${event.clientY}px`
    this.menuTarget.style.left = `${event.clientX}px`
    this.menuTarget.classList.remove("hidden")
    document.addEventListener("click", this.close)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.close)
  }
}
