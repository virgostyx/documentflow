import { Controller } from "@hotwired/stimulus"

// Submits the form as soon as a file is selected, so no explicit upload button is needed.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
