import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sourceSelect", "searchComponent"]

  connect() {
    this.handleSourceSelect()
  }

  handleSourceSelect() {
    if (!this.hasSourceSelectTarget) return

    const selectedValue = this.sourceSelectTarget.value
    
    if (selectedValue === 'not_funded') {
      this.selectNotFundedProject()
    } else {
      this.selectFundedProject(selectedValue)
    }
  }

  selectNotFundedProject() {
    this.setProjectType('not_funded')
    this.clearSourceField()
    this.hideSearchContainer()
    this.clearStoredProjectData()
    this.clearFundingFormData()
    this.dispatchProjectTypeEvent('not_funded')
  }

  selectFundedProject(sourceValue) {
    this.setProjectType('funded')
    this.showSearchContainer()
    this.updateSearchApiValue(sourceValue)
    this.dispatchFundingSourceEvent(sourceValue)
  }

  setProjectType(type) {
    localStorage.setItem('project_type', type)
    const projectTypeField = document.querySelector('[data-project-creation-target="projectTypeField"]')
    if (projectTypeField) {
      projectTypeField.value = type
    }
  }

  clearSourceField() {
    const sourceField = document.getElementById('project_source')
    if (sourceField) {
      sourceField.value = ''
    }
  }

  hideSearchContainer() {
    const searchContainer = document.getElementById('project-search-section')
    if (searchContainer) {
      searchContainer.classList.add('d-none')
    }
  }

  showSearchContainer() {
    const searchContainer = document.getElementById('project-search-section')
    if (searchContainer) {
      searchContainer.classList.remove('d-none')
    }
  }

  clearStoredProjectData() {
    localStorage.removeItem('selectedProjectData')
  }

  updateSearchApiValue(sourceValue) {
    if (this.hasSearchComponentTarget) {
      this.searchComponentTarget.dataset.projectSearchApiValue = sourceValue
    }
  }

  clearFundingFormData() {
    const funderFields = document.querySelectorAll('[name*="funder"], [name*="grant"]')
    funderFields.forEach(field => {
      if (['text', 'hidden', 'email'].includes(field.type)) {
        field.value = ''
      } else if (field.type === 'select-one') {
        field.selectedIndex = 0
      }
    })

    const funderDisplayFields = document.querySelectorAll('[name*="project_funder"]')
    funderDisplayFields.forEach(field => {
      field.value = ''
    })
  }

  dispatchProjectTypeEvent(projectType) {
    document.dispatchEvent(new CustomEvent('project-type-selected', {
      bubbles: true,
      detail: { projectType }
    }))
  }

  dispatchFundingSourceEvent(source) {
    document.dispatchEvent(new CustomEvent('funding-source-changed', {
      bubbles: true,
      detail: { source }
    }))
  }
}