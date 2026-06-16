import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "firstName", "lastName", "email", "company", "phone", "internal"]
  static values = { pickerId: String, url: String, additionalPickerIds: Array }

  toggle() {
    this.panelTarget.classList.toggle("hidden")
  }

  async create() {
    const body = new FormData()
    body.append("picker_id", this.pickerIdValue)
    this.additionalPickerIdsValue.forEach((id) => body.append("additional_picker_ids[]", id))
    body.append("contact[first_name]", this.firstNameTarget.value)
    body.append("contact[last_name]", this.lastNameTarget.value)
    body.append("contact[email]", this.emailTarget.value)
    body.append("contact[company]", this.companyTarget.value)
    body.append("contact[phone]", this.phoneTarget.value)
    body.append("contact[internal]", this.internalTarget.checked ? "1" : "0")

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body
    })

    window.Turbo.renderStreamMessage(await response.text())
  }
}
