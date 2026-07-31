import { Controller } from "@hotwired/stimulus"
import { create } from "@github/webauthn-json"

export default class extends Controller {
  static targets = ["form", "nickname", "error", "backupCodes", "backupCodesList"]
  static values = { optionsUrl: String, createUrl: String }

  async register() {
    this.hideError()
    const nickname = this.nicknameTarget.value.trim()

    if (!nickname) {
      this.showError("Please enter a name for this passkey.")
      return
    }

    const options = await (await fetch(this.optionsUrlValue, { headers: { Accept: "application/json" } })).json()

    let credential
    try {
      credential = await create({ publicKey: options })
    } catch {
      this.showError("Passkey registration was cancelled or failed.")
      return
    }

    const response = await fetch(this.createUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ credential, nickname })
    })
    const result = await response.json()

    if (!response.ok) {
      this.showError(result.error)
      return
    }

    if (result.backup_codes) {
      this.showBackupCodes(result.backup_codes)
    } else {
      window.Turbo.visit(window.location.pathname)
    }
  }

  showBackupCodes(codes) {
    this.formTarget.classList.add("hidden")
    this.backupCodesListTarget.replaceChildren(
      ...codes.map((code) => {
        const li = document.createElement("li")
        li.className = "font-mono text-sm text-center p-2 bg-gray-50 border border-gray-200 rounded"
        li.textContent = code
        return li
      })
    )
    this.backupCodesTarget.classList.remove("hidden")
  }

  done() {
    window.Turbo.visit(window.location.pathname)
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  hideError() {
    this.errorTarget.classList.add("hidden")
  }
}
