import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { downloadUrl: String }

  openDownload() {
    window.open(this.downloadUrlValue, "_blank")
  }
}
