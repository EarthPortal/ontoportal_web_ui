import { Controller } from "@hotwired/stimulus"
// Connects to data-controller="auto-mapping-filter"

export default class extends Controller {
  static targets = ["row", "emptyMessage"]

  toggle(event) {
    const hide = event.target.checked 
    const autoSources = ['LOOM','CUI', 'SAME_URI']
    let count = 0

    this.rowTargets.forEach((row) => {
      const isAutomatic = autoSources.includes(row.dataset.source)   
      row.style.display = hide && isAutomatic ? 'none' : ''

      if(row.style.display === 'none') count++
    })

    if(this.hasEmptyMessageTarget) {
      this.emptyMessageTarget.style.display = count === this.rowTargets.length ? '' : 'none'
    }
  }
}
