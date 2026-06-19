import { Controller } from "@hotwired/stimulus"

// Shows/hides a panel based on a checkbox's checked state, clearing the
// panel's inputs when it's hidden so stale values aren't submitted.
export default class extends Controller {
  static targets = ["checkbox", "panel"]

  connect() {
    this.sync()
  }

  sync() {
    const checked = this.checkboxTarget.checked
    this.panelTarget.classList.toggle("hidden", !checked)
    if (!checked) this._clearPanelInputs()
  }

  _clearPanelInputs() {
    this.panelTarget.querySelectorAll("input, select, textarea").forEach((el) => { el.value = "" })
  }
}
