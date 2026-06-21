import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "row", "empty"]

  connect() {
    this.filter()
  }

  filter() {
    const query = (this.hasSearchTarget ? this.searchTarget.value : "").trim().toLowerCase()

    if (query === "") {
      this.rowTargets.forEach((row) => { row.style.display = "" })
      this.toggleEmpty(false)
      return
    }

    const matches = this.rowTargets.filter((row) => row.dataset.searchableText.includes(query))
    this.rowTargets.forEach((row) => { row.style.display = "none" })
    matches.forEach((row) => this.revealWithAncestors(row))

    this.toggleEmpty(matches.length === 0)
  }

  revealWithAncestors(row) {
    row.style.display = ""

    // Each row's wrapper sits beside its parent's row inside the parent's own wrapper
    // (rows and child wrappers are siblings, not ancestors), so climb one wrapper level
    // at a time and pull out that wrapper's own direct row child.
    let wrapper = row.parentElement

    while (wrapper) {
      const parentWrapper = wrapper.parentElement
      if (!parentWrapper) break

      const parentRow = parentWrapper.querySelector(':scope > [data-classification-picker-target="row"]')
      if (!parentRow) break

      parentRow.style.display = ""
      wrapper = parentWrapper
    }
  }

  toggleEmpty(show) {
    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("hidden", !show)
  }
}
