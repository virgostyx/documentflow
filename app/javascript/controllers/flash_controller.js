import { Controller } from "@hotwired/stimulus"

// Toast animé : barre de progression qui se vide, pause au survol, fermeture manuelle
export default class extends Controller {
  static targets = ["progress"]
  static values = { duration: Number }

  connect() {
    this.remaining = this.durationValue
    this.start()
  }

  disconnect() {
    this.stop()
  }

  start() {
    this.startedAt = Date.now()
    this.progressTarget.style.transition = "none"
    this.progressTarget.style.width = "100%"
    // Force reflow so the transition below animates from 100% to 0%
    this.progressTarget.offsetWidth
    this.progressTarget.style.transition = `width ${this.remaining}ms linear`
    this.progressTarget.style.width = "0%"
    this.timeout = setTimeout(() => this.close(), this.remaining)
  }

  pause() {
    this.stop()
    this.remaining -= Date.now() - this.startedAt
    this.progressTarget.style.transition = "none"
    this.progressTarget.style.width = getComputedStyle(this.progressTarget).width
  }

  resume() {
    if (this.remaining > 0) this.start()
  }

  stop() {
    clearTimeout(this.timeout)
  }

  close() {
    this.stop()
    this.element.remove()
  }
}
