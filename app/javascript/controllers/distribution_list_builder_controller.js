import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["members", "member", "template", "entitySelect", "partyPicker"]

  connect() {
    this.sortable = Sortable.create(this.membersTarget, {
      animation: 150,
      handle: ".drag-handle",
      filter: ".hidden",
      onEnd: () => this.updateOrder()
    })

    if (this.hasEntitySelectTarget) this.switchEntity()
  }

  disconnect() {
    this.sortable?.destroy()
  }

  switchEntity() {
    const entityId = this.entitySelectTarget.value
    this.partyPickerTargets.forEach((select) => {
      select.classList.toggle("hidden", select.dataset.entityId !== entityId)
    })
  }

  activePartyPicker() {
    return this.partyPickerTargets.find((select) => !select.classList.contains("hidden"))
  }

  addMember() {
    const picker = this.activePartyPicker()
    if (!picker || !picker.value) return

    const label = picker.options[picker.selectedIndex].text
    const timestamp = new Date().getTime()
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, timestamp)
    this.membersTarget.insertAdjacentHTML("beforeend", content)

    const row = this.memberTargets[this.memberTargets.length - 1]
    row.querySelector('[data-distribution-list-builder-target="partyToken"]').value = picker.value
    row.querySelector('[data-distribution-list-builder-target="partyLabel"]').textContent = label

    picker.selectedIndex = 0
    this.updateOrder()
  }

  removeMember(event) {
    const row = event.target.closest('[data-distribution-list-builder-target="member"]')
    const destroyField = row.querySelector('[data-distribution-list-builder-target="destroy"]')
    const idField = row.querySelector('input[name*="[id]"]')

    if (idField && idField.value) {
      destroyField.value = "1"
      row.classList.add("hidden")
    } else {
      row.remove()
    }

    this.updateOrder()
  }

  updateOrder() {
    this.memberTargets
      .filter((row) => !row.classList.contains("hidden"))
      .forEach((row, index) => {
        const positionField = row.querySelector('[data-distribution-list-builder-target="position"]')
        if (positionField) positionField.value = index + 1
      })
  }
}
