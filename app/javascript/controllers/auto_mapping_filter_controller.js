import { Controller } from "@hotwired/stimulus"
// Connects to data-controller="auto-mapping-filter"

export default class extends Controller {
  static targets = ["row"]

  toggle(event) {
    const hide = event.target.checked 

    const autoSources = ['LOOM','CUI', 'SAME_URI']

    this.rowTargets.forEach((row) => {
      const isAutomatic = autoSources.includes(row.dataset.source)   

      row.style.display = hide && isAutomatic ? 'none' : ''
    })
  }
}
