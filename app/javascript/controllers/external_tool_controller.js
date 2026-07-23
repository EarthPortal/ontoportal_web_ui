import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  async connect(event) {
    event.preventDefault()

    // Open the tab immediately on click, otherwise the browser blocks
    // window.open() once the fetch response arrives
    const externalToolTab = window.open('', '_blank')

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch(this.urlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        }
      })

      const data = await response.json()

      if (response.ok && data.redirectUrl) {
        externalToolTab.location = data.redirectUrl
      } else {
        externalToolTab.close()
        const message = typeof data.error === 'string' ? data.error : JSON.stringify(data.error)
        this.#showError(message, data.link, data.link_label)
      }
    } catch (err) {
      externalToolTab.close()
      this.#showError(err.message)
    }
  }

  #showError(message, link = null, linkLabel = null) {
    const container = document.getElementById('external-tool-error')
    if (!container) {
      alert(message)
      return
    }

    const text = container.querySelector('.notification-text p')
    text.textContent = message

    if (link) {
      const anchor = document.createElement('a')
      anchor.href = link
      anchor.textContent = ' ' + (linkLabel || link)
      text.appendChild(anchor)
    }

    container.classList.remove('d-none')
    // hide it back so the notification can be shown again on the next click
    setTimeout(() => container.classList.add('d-none'), 8000)
  }
}
