import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "chevron"]
  static values = { key: String, open: Boolean, active: Boolean }

  connect() {
    if (this.activeValue) {
      this._setOpen(true)
      if (this.hasKeyValue) localStorage.setItem(this._storageKey, true)
      return
    }

    const stored = this._storedOpen()
    this._setOpen(stored === null ? this.openValue : stored)
  }

  toggle() {
    const open = this.panelTarget.classList.contains("hidden")
    this._setOpen(open)
    if (this.hasKeyValue) localStorage.setItem(this._storageKey, open)
  }

  _storedOpen() {
    if (!this.hasKeyValue) return null
    const stored = localStorage.getItem(this._storageKey)
    return stored === null ? null : stored === "true"
  }

  get _storageKey() {
    return `sidebar-section-${this.keyValue}-open`
  }

  _setOpen(open) {
    if (open) {
      this.panelTarget.classList.remove("hidden")
      if (this.hasChevronTarget) this.chevronTarget.style.transform = "rotate(180deg)"
    } else {
      this.panelTarget.classList.add("hidden")
      if (this.hasChevronTarget) this.chevronTarget.style.transform = "rotate(0deg)"
    }
  }
}
