// Custom Turbo confirmation handler
// Intercepts confirmation requests and shows custom modal

document.addEventListener('click', (event) => {
  const element = event.target.closest('[data-turbo-confirm]')

  if (!element) return

  const confirmMessage = element.getAttribute('data-turbo-confirm')

  event.preventDefault()
  event.stopPropagation()

  showConfirmModal(confirmMessage).then((confirmed) => {
    if (confirmed) {
      element.removeAttribute('data-turbo-confirm')

      const newEvent = new MouseEvent('click', {
        bubbles: true,
        cancelable: true,
        view: window
      })

      element.dispatchEvent(newEvent)

      setTimeout(() => {
        element.setAttribute('data-turbo-confirm', confirmMessage)
      }, 500)
    }
  })
}, true) // Use capture phase to intercept before Turbo

function showConfirmModal(messageOrOptions) {
  const isString = typeof messageOrOptions === 'string'
  const message = isString ? messageOrOptions : messageOrOptions.message
  const details = isString ? null : messageOrOptions.details

  return new Promise((resolve) => {
    const modal = document.getElementById('confirm-modal')
    const messageElement = modal?.querySelector('[data-confirm-target="message"]')

    if (!modal || !messageElement) {
      resolve(window.confirm(message))
      return
    }

    window.confirmResolver = resolve

    messageElement.textContent = message

    const detailsEl = modal.querySelector('[data-confirm-target="details"]')
    if (detailsEl) {
      detailsEl.innerHTML = ''
      if (details && details.length > 0) {
        details.forEach(({ label, value }) => {
          const row = document.createElement('div')
          row.className = 'flex items-baseline gap-2 px-3 py-2'

          const labelEl = document.createElement('span')
          labelEl.className = 'text-xs font-medium text-gray-500 w-24 shrink-0'
          labelEl.textContent = label

          const valueEl = document.createElement('span')
          valueEl.className = 'text-sm text-gray-900 font-medium flex-1'
          valueEl.textContent = value

          row.appendChild(labelEl)
          row.appendChild(valueEl)
          detailsEl.appendChild(row)
        })
        detailsEl.classList.remove('hidden')
      } else {
        detailsEl.classList.add('hidden')
      }
    }

    modal.classList.remove('hidden')
    document.body.style.overflow = 'hidden'

    const confirmButton = modal.querySelector('[data-confirm-target="confirmButton"]')
    if (confirmButton) {
      setTimeout(() => confirmButton.focus(), 100)
    }
  })
}

window.showConfirmModal = showConfirmModal
