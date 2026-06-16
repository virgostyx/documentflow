import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      handle: ".drag-handle",
      onEnd: () => this.reorder()
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  reorder() {
    const items = this.element.querySelectorAll("[data-step-id]")
    items.forEach((el, index) => {
      const badge = el.querySelector("[data-order-badge]")
      if (badge) badge.textContent = index + 1
    })

    const stepIds = Array.from(items).map(el => el.dataset.stepId)
    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content
      },
      body: JSON.stringify({ step_ids: stepIds })
    })
  }
}
