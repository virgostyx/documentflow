import { Controller } from "@hotwired/stimulus"
import { get } from "@github/webauthn-json"

export default class extends Controller {
  static targets = ["status", "form", "tokenField"]
  static values = { optionsUrl: String, verifyUrl: String }

  async verify() {
    this.hideStatus()

    const options = await (await fetch(this.optionsUrlValue, { headers: { Accept: "application/json" } })).json()

    let credential
    try {
      credential = await get({ publicKey: options })
    } catch (error) {
      if (error.name !== "AbortError") this.showStatus("Verification was cancelled or failed.")
      return
    }

    const response = await fetch(this.verifyUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ credential })
    })
    const result = await response.json()

    if (response.ok) {
      this.tokenFieldTarget.value = result.step_up_token
      this.formTarget.requestSubmit()
    } else {
      this.showStatus(result.error)
    }
  }

  showStatus(message) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.classList.remove("hidden")
  }

  hideStatus() {
    if (!this.hasStatusTarget) return
    this.statusTarget.classList.add("hidden")
  }
}
