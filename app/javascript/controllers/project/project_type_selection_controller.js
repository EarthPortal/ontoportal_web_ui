import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fundedRadio", "notFundedRadio"]
  
  connect() {
    const storedType = localStorage.getItem('project_type')
    if (storedType) {
      if (storedType === 'funded' && this.hasFundedRadioTarget) {
        this.fundedRadioTarget.checked = true
      } else if (storedType === 'not_funded' && this.hasNotFundedRadioTarget) {
        this.notFundedRadioTarget.checked = true
      }
    }
  }
  
  selectType(event) {
    const projectType = event.currentTarget.value
    localStorage.setItem('project_type', projectType)
    
    if (projectType === "not_funded") {
      window.location.href = "/projects/new?step=3"
    }
  }
}