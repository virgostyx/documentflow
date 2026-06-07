import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["input", "label"]

    connect() {
        this.checkValue()
    }

    checkValue() {
        if (this.inputTarget.value.trim() !== "" ||
            this.inputTarget === document.activeElement) {
            this.labelTarget.classList.add("floating")
        } else {
            this.labelTarget.classList.remove("floating")
        }
    }

    focus() {
        this.labelTarget.classList.add("floating")
    }

    blur() {
        this.checkValue()
    }
}