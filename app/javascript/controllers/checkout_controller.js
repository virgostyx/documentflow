import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { downloadUrl: String }

  openDownload() {
    const link = document.createElement("a")
    link.href = this.downloadUrlValue
    link.download = ""
    document.body.appendChild(link)
    link.click()
    link.remove()
  }
}
