import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["steps", "step", "template"]

  connect() {
    this.sortable = Sortable.create(this.stepsTarget, {
      animation: 150,
      handle: ".drag-handle",
      filter: ".hidden",
      onEnd: () => this.updateOrder()
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  addStep() {
    const timestamp = new Date().getTime()
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, timestamp)
    this.stepsTarget.insertAdjacentHTML("beforeend", content)
    this.updateOrder()
  }

  removeStep(event) {
    const step = event.target.closest('[data-workflow-builder-target="step"]')
    const destroyField = step.querySelector('[data-workflow-builder-target="destroy"]')
    const idField = step.querySelector('input[name*="[id]"]')

    if (idField && idField.value) {
      destroyField.value = "1"
      step.classList.add("hidden")
    } else {
      step.remove()
    }

    this.updateOrder()
  }

  updateOrder() {
    this.stepTargets
      .filter((step) => !step.classList.contains("hidden"))
      .forEach((step, index) => {
        const orderField = step.querySelector('[data-workflow-builder-target="order"]')
        if (orderField) orderField.value = index + 1
      })
  }
}
