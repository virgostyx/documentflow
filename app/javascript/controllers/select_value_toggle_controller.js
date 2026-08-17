import { Controller } from "@hotwired/stimulus"

// Shows/hides a panel based on whether a select's value matches a given value,
// clearing the panel's inputs when it's hidden so stale values aren't submitted.
export default class extends Controller {
  static targets = ["panel"]
  static values = { match: String }

  connect() {
    this.sync()
  }

  sync() {
    const matches = this.element.querySelector("select").value === this.matchValue
    this.panelTarget.classList.toggle("hidden", !matches)
    if (!matches) this._clearPanelInputs()
  }

  _clearPanelInputs() {
    this.panelTarget.querySelectorAll("input, select, textarea").forEach((el) => { el.value = "" })
  }
}
