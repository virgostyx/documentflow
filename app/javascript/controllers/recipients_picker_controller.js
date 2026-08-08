import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "row", "empty"]

  filter() {
    const query = this.searchTarget.value.trim().toLowerCase()
    const matches = this.rowTargets.filter((row) => row.dataset.searchableText.includes(query))

    this.rowTargets.forEach((row) => { row.style.display = "none" })
    matches.forEach((row) => { row.style.display = "" })

    this.toggleEmpty(query !== "" && matches.length === 0)
  }

  toggleEmpty(show) {
    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("hidden", !show)
  }
}
