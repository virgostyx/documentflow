import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.outsideClick = this.outsideClick.bind(this)
  }

  toggle() {
    this.menuTarget.classList.toggle("hidden")
    if (!this.menuTarget.classList.contains("hidden")) {
      document.addEventListener("click", this.outsideClick)
    }
  }

  close() {
    this.menuTarget.classList.add("hidden")
    document.removeEventListener("click", this.outsideClick)
  }

  outsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClick)
  }
}
