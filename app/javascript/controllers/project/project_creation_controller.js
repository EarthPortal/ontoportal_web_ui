import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "projectData", "name", "acronym", "description", 
    "startDate", "endDate", "organization", "contact", 
    "homePage", "keywords", "grantNumber", "funder",
    "isFunded", "fundingSource", "steps", "progressBar", "progressItem"
  ]
  
  static values = {
    currentStep: Number
  }
   
  connect() {
    document.addEventListener('project-type-selected', this.handleProjectTypeSelection.bind(this))
    document.addEventListener("project-selected", this.handleProjectSelection.bind(this))
    document.addEventListener("skip-to-step", this.handleSkipToStep.bind(this))
    
    if (this.element) {
      this.element.addEventListener("populate-project-form", this.populateProjectForm.bind(this))
      this.element.addEventListener("show-summary-modal", this.showSubmissionSummary.bind(this))
    }
    
    this.initializeForm()
    this.setupLogoPreview()
    this.currentStepValue = parseInt(new URLSearchParams(window.location.search).get('step') || 1)
    this.updateStepsVisibility()
    this.updateProgressUI()
    setTimeout(() => this.populateProjectForm(), 300)
  }
  
  disconnect() {
    document.removeEventListener('project-type-selected', this.handleProjectTypeSelection.bind(this))
    document.removeEventListener("project-selected", this.handleProjectSelection.bind(this))
    document.removeEventListener("skip-to-step", this.handleSkipToStep.bind(this))
    
    const logoInput = this.element.querySelector('input[name="project[logo]"]')
    if (logoInput) logoInput.removeEventListener('input', this.updateLogoPreview.bind(this))
    
    if (this.element) {
      this.element.removeEventListener("populate-project-form", this.populateProjectForm.bind(this))
      this.element.removeEventListener("show-summary-modal", this.showSubmissionSummary.bind(this))
    }
  }

  initializeForm() {
    if (this.hasIsFundedTarget) this.isFundedTarget.value = "false"
    if (this.hasFundingSourceTarget) this.fundingSourceTarget.value = ""
    if (this.hasProjectDataTarget) this.projectDataTarget.value = "{}"
  }

  setupLogoPreview() {
    const logoUrlContainer = this.element.querySelector('.logo-url-container')
    if (!logoUrlContainer) return
    
    const logoInput = logoUrlContainer.querySelector('input[name="project[logo]"]')
    if (!logoInput) return
    
    logoInput.setAttribute('data-project-creation-target', 'logoInput')
    logoInput.addEventListener('input', this.updateLogoPreview.bind(this))
    if (logoInput.value) setTimeout(() => this.updateLogoPreview(), 100)
  }
  
  showSubmissionSummary() {
    const modal = document.getElementById("submissionModal")
    if (modal) new bootstrap.Modal(modal).show()
  }
  
  submitProjectForm() {
    const form = this.element.closest('form')
    if (form) {
      const modal = bootstrap.Modal.getInstance(document.getElementById('submissionModal'))
      if (modal) modal.hide()
      form.requestSubmit()
    }
  }
  
  handleProjectSelection(event) {
    if (!event.detail?.projectData) return
    
    const projectData = event.detail.projectData
    localStorage.setItem('project_type', 'funded')
    
    const projectTypeField = document.querySelector('[data-project-creation-target="projectTypeField"]')
    if (projectTypeField) projectTypeField.value = 'funded'
    
    if (this.hasProjectDataTarget) this.projectDataTarget.value = JSON.stringify(projectData)
    this.storeSelectedProject(projectData)
  }
  
  storeSelectedProject(projectData) {
    if (!projectData) return
    
    const projectDataField = document.querySelector('input[name="project_data"]')
    if (projectDataField) projectDataField.value = JSON.stringify(projectData)
    localStorage.setItem('selectedProject', JSON.stringify(projectData))
  }
  
  populateProjectForm() {
    if (!this.element.dataset.mode || this.element.dataset.mode === "edit") return
    
    const projectType = localStorage.getItem('project_type')
    const storedData = localStorage.getItem('selectedProjectData')
    
    this.clearFormFields()
    this.makeFieldsEditable()
    
    if (projectType === 'funded' && storedData) {
      this.populateFundedProjectData(JSON.parse(storedData))
    }
  }

  clearFormFields() {
    const fields = [
      'name', 'acronym', 'description', 'contact', 'homePage', 'grantNumber'
    ]
    
    fields.forEach(field => {
      if (this[`has${field.charAt(0).toUpperCase() + field.slice(1)}Target`]) {
        this.fillField(this[`${field}Target`], "")
      }
    })
    
    if (this.hasStartDateTarget) this.fillDateField(this.startDateTarget, "")
    if (this.hasEndDateTarget) this.fillDateField(this.endDateTarget, "")
  }

  makeFieldsEditable() {
    const editableFields = ['acronym', 'grantNumber', 'funder']
    editableFields.forEach(field => {
      if (this[`has${field.charAt(0).toUpperCase() + field.slice(1)}Target`]) {
        this.makeFieldEditable(this[`${field}Target`])
      }
    })
  }

  populateFundedProjectData(projectData) {
    const fieldMappings = {
      name: 'name',
      acronym: 'acronym', 
      description: 'description',
      contact: 'contact',
      homePage: 'homePage',
      grantNumber: 'grant_number'
    }

    Object.entries(fieldMappings).forEach(([targetField, dataField]) => {
      if (this[`has${targetField.charAt(0).toUpperCase() + targetField.slice(1)}Target`]) {
        this.fillField(this[`${targetField}Target`], projectData[dataField] || "")
      }
    })

    if (this.hasStartDateTarget) this.fillDateField(this.startDateTarget, projectData.start_date || "")
    if (this.hasEndDateTarget) this.fillDateField(this.endDateTarget, projectData.end_date || "")

    this.populateFunderData(projectData)
    this.populateOrganizationData(projectData)
    this.populateKeywordsData(projectData)
    this.setSourceField(projectData)
    this.makeReadOnlyFields()
  }

  populateFunderData(projectData) {
    if (projectData.funder && this.hasFunderTarget) {
      const funderInput = this.funderTarget.querySelector('input[name="project_funder_display"]')
      const funderIdField = document.getElementById("project_funders_attributes_0_id")
      
      if (funderIdField) funderIdField.value = projectData.funder.id 
      if (funderInput) {
        funderInput.value = projectData.funder.name
        funderInput.readOnly = true
      }
    }
  }

  populateOrganizationData(projectData) {
    const organizationField = this.element.querySelector('.organization-project-input-field')
    const searchInput = organizationField?.querySelector('input[type="text"]')
    
    if (searchInput) {
      searchInput.value = ""
      this.triggerInputEvents(searchInput)
      
      if (projectData.organization?.name) {
        searchInput.value = projectData.organization.name
        this.triggerInputEvents(searchInput)
      }
    }
  }

  populateKeywordsData(projectData) {
    if (!this.hasKeywordsTarget) return
    
    const select = this.keywordsTarget.querySelector('select')
    if (!select) return
    
    select.innerHTML = ''
    const allKeywords = projectData.all_keywords || projectData.keywords || []
    const selectedKeywords = projectData.keywords || []
    
    allKeywords.forEach(keyword => {
      const option = document.createElement('option')
      option.value = keyword
      option.text = keyword
      if (selectedKeywords.includes(keyword)) option.selected = true
      select.appendChild(option)
    })
    
    if (select.tomselect) {
      select.tomselect.clear()
      allKeywords.forEach(keyword => {
        if (!select.tomselect.options[keyword]) {
          select.tomselect.addOption({ value: keyword, text: keyword })
        }
      })
      select.tomselect.setValue(selectedKeywords)
    } else {
      select.dispatchEvent(new Event('change', { bubbles: true }))
    }
  }

  setSourceField(projectData) {
    const sourceField = document.getElementById('project_source')
    if (sourceField && projectData.source) sourceField.value = projectData.source
  }

  makeReadOnlyFields() {
    const readOnlyFields = ['acronym', 'grantNumber', 'funder']
    readOnlyFields.forEach(field => {
      if (this[`has${field.charAt(0).toUpperCase() + field.slice(1)}Target`]) {
        this.makeFieldReadOnly(this[`${field}Target`])
      }
    })
  }

  triggerInputEvents(element) {
    element.dispatchEvent(new Event('change', { bubbles: true }))
    element.dispatchEvent(new Event('input', { bubbles: true }))
  }
  
  makeFieldReadOnly(targetElement) {
    if (!targetElement) return
    
    const input = targetElement.querySelector('input, textarea')
    if (!input) return
    
    input.setAttribute('readonly', 'readonly')
    input.readOnly = true
    input.classList.add('bg-light')
    
    const container = targetElement.closest('.upload-ontology-input-field-container')
    if (container) {
      container.classList.add('readonly-field')
      this.addAutoFilledBadge(container)
    }
  }

  addAutoFilledBadge(container) {
    const label = container.querySelector('label')
    if (label && !label.querySelector('.badge')) {
      const badge = document.createElement('span')
      badge.className = 'badge bg-secondary ms-2 small'
      badge.textContent = 'Auto-filled'
      label.appendChild(badge)
    }
  }
  
  makeFieldEditable(targetElement) {
    if (!targetElement) return
    
    const input = targetElement.querySelector('input, textarea')
    if (!input) return
    
    input.removeAttribute('readonly')
    input.readOnly = false
    input.classList.remove('bg-light')
    
    const container = targetElement.closest('.upload-ontology-input-field-container')
    if (container) {
      container.classList.remove('readonly-field')
      const badge = container.querySelector('label .badge')
      if (badge) badge.remove()
    }
  }
  
  fillField(targetElement, value) {
    const input = targetElement.querySelector('input, textarea, select')
    if (input) {
      input.value = value
      this.triggerInputEvents(input)
    }
  }
  
  fillDateField(targetElement, dateValue) {
    const formattedDate = dateValue.includes('T') ? dateValue.split('T')[0] : dateValue
    const input = targetElement.querySelector('input[type="date"]')
    if (input) {
      input.value = formattedDate
      input.dispatchEvent(new Event('change', { bubbles: true }))
    }
  }

  updateLogoPreview() {
    const logoInput = this.element.querySelector('[data-project-creation-target="logoInput"]')
    if (!logoInput) return
    
    const url = logoInput.value.trim()
    const previewImg = this.element.querySelector('[data-project-creation-target="logoPreview"]')
    const placeholder = this.element.querySelector('[data-project-creation-target="logoPlaceholder"]')
    
    if (!previewImg || !placeholder) return
    
    if (url) {
      previewImg.src = url
      previewImg.onload = () => {
        previewImg.classList.remove('d-none')
        placeholder.classList.add('d-none')
      }
      previewImg.onerror = () => {
        previewImg.classList.add('d-none')
        placeholder.classList.remove('d-none')
      }
    } else {
      previewImg.classList.add('d-none')
      placeholder.classList.remove('d-none')
    }
  }
  
  handleSkipToStep(event) {
    if (!event.detail?.step) return
    this.skipToStep(event.detail.step)
  }
  
  skipToStep(stepNumber) {
    this.currentStepValue = stepNumber
    this.updateStepsVisibility()
    this.updateProgressUI()
    this.updateURL()
    window.scrollTo({
      top: this.element.offsetTop - 20,
      behavior: 'smooth'
    })
  }
  
  updateStepsVisibility() {
    if (this.hasStepsTarget) {
      this.stepsTargets.forEach((step, index) => {
        step.classList.toggle('d-none', index + 1 !== this.currentStepValue)
      })
    }
  }
  
  updateProgressUI() {
    if (this.hasProgressItemTarget) {
      this.progressItemTargets.forEach((item, index) => {
        const itemStep = index + 1
        item.classList.toggle('active', itemStep === this.currentStepValue)
        item.classList.toggle('completed', itemStep < this.currentStepValue)
      })
    }
    
    if (this.hasProgressBarTarget) {
      const totalSteps = this.progressItemTargets?.length || 4
      const percentComplete = ((this.currentStepValue - 1) / (totalSteps - 1)) * 100
      this.progressBarTarget.style.width = `${percentComplete}%`
    }
  }
  
  updateURL() {
    const url = new URL(window.location)
    url.searchParams.set('step', this.currentStepValue)
    history.pushState({}, '', url)
  }
  
  nextStep() {
    this.skipToStep(this.currentStepValue + 1)
  }
  
  previousStep() {
    if (this.currentStepValue === 3 && this.hasIsFundedTarget && this.isFundedTarget.value === "false") {
      this.skipToStep(1)
    } else {
      this.skipToStep(this.currentStepValue - 1)
    }
  }

  handleProjectTypeSelection(event) {
    const { projectType } = event.detail
    
    if (projectType === 'not_funded') {
      this.hideFundingFields()
    } else {
      this.showFundingFields()
    }
  }

  hideFundingFields() {
    const fundingFields = document.querySelectorAll('.funding-related-field')
    fundingFields.forEach(field => field.classList.add('d-none'))
  }

  showFundingFields() {
    const fundingFields = document.querySelectorAll('.funding-related-field')
    fundingFields.forEach(field => field.classList.remove('d-none'))
  }
}