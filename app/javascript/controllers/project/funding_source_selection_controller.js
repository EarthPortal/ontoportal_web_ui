import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sourceSelect", "searchComponent"]

  connect() {
    if (this.hasSourceSelectTarget && this.hasSearchComponentTarget) {
      const selectedId = this.sourceSelectTarget.value
      this.searchComponentTarget.setAttribute('data-project-search-api-value', selectedId)
    }
  }

  selectNotFundedProject(event) {
    event.preventDefault()
    localStorage.setItem('project_type', 'not_funded')
    
    // Set the hidden field
    const projectTypeField = document.querySelector('[data-project-creation-target="projectTypeField"]')
    if (projectTypeField) {
      projectTypeField.value = 'not_funded'
    }
    
    // Clear source field for non-funded projects
    const sourceField = document.getElementById('project_source')
    if (sourceField) {
      sourceField.value = ''
    }
    
    localStorage.removeItem('selectedProjectData')

    localStorage.removeItem('selectedProject')
    const projectDataField = document.querySelector('input[name="project_data"]')
    if (projectDataField) projectDataField.value = "{}"
    const nextButton = document.querySelector('[data-progress-pages-target="nextBtn"]')
    if (nextButton) {
      nextButton.click()
      setTimeout(() => {
        const projectCreationElement = document.querySelector('[data-controller="project-creation"]')
        if (projectCreationElement) {
          const inputs = projectCreationElement.querySelectorAll('input[type="text"], input[type="date"], textarea, select')
          inputs.forEach(input => {
            if (input.type === 'text' || input.type === 'date' || input.tagName === 'TEXTAREA') {
              input.value = ''
            } else if (input.tagName === 'SELECT' && input.tomselect) {
              input.tomselect.clear()
            }
          })
          const readOnlyInputs = projectCreationElement.querySelectorAll('input[readonly]')
          readOnlyInputs.forEach(input => {
            input.removeAttribute('readonly')
            input.classList.remove('bg-light')
          })
          const organizationField = projectCreationElement.querySelector('.organization-project-input-field')
          const searchInput = organizationField?.querySelector('input[type="text"]')
          if (searchInput) searchInput.value = ""
          const funderField = projectCreationElement.querySelector('input[name="project_funders_attributes_0_id"]')
          if (funderField) funderField.value = ""
          const logoPreview = projectCreationElement.querySelector('[data-project-creation-target="logoPreview"]')
          const logoPlaceholder = projectCreationElement.querySelector('[data-project-creation-target="logoPlaceholder"]')
          if (logoPreview && logoPlaceholder) {
            logoPreview.classList.add('d-none')
            logoPreview.src = ''
            logoPlaceholder.classList.remove('d-none')
          }
        }
      }, 200)
    }
  }

  handleSourceSelect(event) {
    const selectedId = event.target.value
    if (this.hasSearchComponentTarget) {
      this.searchComponentTarget.setAttribute('data-project-search-api-value', selectedId)
      const resultsList = this.searchComponentTarget.querySelector('[data-project-search-target="resultsList"]')
      if (resultsList) resultsList.innerHTML = ''
      const resultsContainer = this.searchComponentTarget.querySelector('[data-project-search-target="results"]')
      if (resultsContainer) resultsContainer.classList.add('d-none')
    }
  }
}