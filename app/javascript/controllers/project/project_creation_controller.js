import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "projectData", "name", "acronym", "description", 
    "startDate", "endDate", "organization", "contact", 
    "homePage", "keywords", "grantNumber", "funder",
    "fundedRadio", "notFundedRadio", "fundingSourceRadio", 
    "isFunded", "fundingSource", "steps", "progressBar", "progressItem",
    "logoInput", "logoPreview", "logoPlaceholder", "summaryModal"
  ]
  
  static values = {
    currentStep: Number
  }
   
  connect() {
    if (this.hasIsFundedTarget) {
      this.isFundedTarget.value = "false"
    }
    
    if (this.hasFundingSourceTarget) {
      this.fundingSourceTarget.value = ""
    }
    
    if (this.hasProjectDataTarget) {
      this.projectDataTarget.value = JSON.stringify({})
    }
    
    this.setupLogoPreview();
    
    const urlParams = new URLSearchParams(window.location.search)
    this.currentStepValue = parseInt(urlParams.get('step') || 1)
    
    document.addEventListener("project-selected", this.handleProjectSelection.bind(this))
    document.addEventListener("skip-to-step", this.handleSkipToStep.bind(this))
    document.addEventListener("project-selected", this.handleProjectSelected.bind(this))
    
    if (this.element) {
      this.element.addEventListener("populate-project-form", this.populateProjectForm.bind(this))
      this.element.addEventListener("show-summary-modal", this.showSubmissionSummary.bind(this))
    }
    
    this.updateStepsVisibility()
    this.updateProgressUI()
    
    setTimeout(() => this.populateProjectForm(), 300)
  }
  
  disconnect() {
    document.removeEventListener("project-selected", this.handleProjectSelection.bind(this))
    document.removeEventListener("skip-to-step", this.handleSkipToStep.bind(this))
    document.removeEventListener("project-selected", this.handleProjectSelected.bind(this))
    
    const logoInput = this.element.querySelector('input[name="project[logo]"]');
    if (logoInput) {
      logoInput.removeEventListener('input', this.updateLogoPreview.bind(this));
    }

    if (this.element) {
      this.element.removeEventListener("populate-project-form", this.populateProjectForm.bind(this))
      this.element.removeEventListener("show-summary-modal", this.showSubmissionSummary.bind(this))
    }
    
  }

  setupLogoPreview() {
    const logoUrlContainer = this.element.querySelector('.logo-url-container');
    if (!logoUrlContainer) return;
    
    const logoInput = logoUrlContainer.querySelector('input[name="project[logo]"]');
    if (!logoInput) return;
    
    logoInput.setAttribute('data-project-creation-target', 'logoInput');
    logoInput.addEventListener('input', this.updateLogoPreview.bind(this));
    
    if (logoInput.value) {
      setTimeout(() => this.updateLogoPreview(), 100);
    }
  }
  
  
  showSummaryModal() {
    const modal = document.getElementById("submissionModal")
    if (modal) {
      const bsModal = new bootstrap.Modal(modal)
      bsModal.show()
    }
  }
  
  submitProjectForm() {
    const form = this.element.closest('form')
    if (form) {
      const modal = bootstrap.Modal.getInstance(document.getElementById('submissionModal'))
      if (modal) {
        modal.hide()
      }
      form.requestSubmit()
    }
  }
  
  showSubmissionSummary() {
    const modal = document.getElementById("submissionModal")
    if (modal) {
      const bsModal = new bootstrap.Modal(modal)
      bsModal.show()
    }
  }
  
  handleFundedSelection(event) {
    const isFunded = event.currentTarget.value === "funded"
    
    if (this.hasIsFundedTarget) {
      this.isFundedTarget.value = isFunded.toString()
    }
    
    localStorage.setItem('project_type', isFunded ? 'funded' : 'not_funded')
    
    if (isFunded) {
      if (this.hasAcronymTarget) this.makeFieldReadOnly(this.acronymTarget)
      if (this.hasGrantNumberTarget) this.makeFieldReadOnly(this.grantNumberTarget)
      if (this.hasFunderTarget) this.makeFieldReadOnly(this.funderTarget)
    } else {
      if (this.hasAcronymTarget) this.makeFieldEditable(this.acronymTarget)
      if (this.hasGrantNumberTarget) this.makeFieldEditable(this.grantNumberTarget)
      if (this.hasFunderTarget) this.makeFieldEditable(this.funderTarget)
      this.skipToStep(3)
    }
  }
  
  handleFundingSourceSelection(event) {
    if (this.hasFundingSourceTarget) {
      this.fundingSourceTarget.value = event.currentTarget.value
    }
  }
  
  handleProjectSelection(event) {
    if (!event.detail?.projectData) return
    
    const projectData = event.detail.projectData
    
    if (this.hasProjectDataTarget) {
      this.projectDataTarget.value = JSON.stringify(projectData)
    }
    
    this.storeSelectedProject(projectData)
  }
  
  handleProjectSelected(event) {
    if (!event.detail?.projectData) return
    
    if (this.hasProjectDataTarget) {
      this.projectDataTarget.value = JSON.stringify(event.detail.projectData)
    }
  }
  
  storeSelectedProject(projectData) {
    if (!projectData) return
    
    const projectDataField = document.querySelector('input[name="project_data"]')
    if (projectDataField) {
      projectDataField.value = JSON.stringify(projectData)
    }
    
    localStorage.setItem('selectedProject', JSON.stringify(projectData))
  }
  
  populateProjectForm() {
    try {
      const storedData = localStorage.getItem('selectedProjectData')
      if (!storedData) return
  
      const projectData = JSON.parse(storedData)
  
      // Populate simple fields
      if (this.hasNameTarget) this.fillField(this.nameTarget, projectData.name || projectData.title)
      if (this.hasAcronymTarget) this.fillField(this.acronymTarget, projectData.acronym)
      if (this.hasDescriptionTarget) this.fillField(this.descriptionTarget, projectData.description)
      if (this.hasStartDateTarget && projectData.start_date) this.fillDateField(this.startDateTarget, projectData.start_date)
      if (this.hasEndDateTarget && projectData.end_date) this.fillDateField(this.endDateTarget, projectData.end_date)
      if (this.hasContactTarget) this.fillField(this.contactTarget, projectData.contact || projectData.coordinator)
      if (this.hasHomePageTarget) this.fillField(this.homePageTarget, projectData.homePage || projectData.homepage)
      if (this.hasGrantNumberTarget) this.fillField(this.grantNumberTarget, projectData.grant_number || "")
      if (this.hasFunderTarget) {
        let funderValue = projectData.funder || ""
        if (typeof funderValue === 'object' && funderValue.name) funderValue = funderValue.name
        this.fillField(this.funderTarget, funderValue)
      }
  
      // Populate organization
      if (projectData.organization) {
        const organizationField = this.element.querySelector('.organization-project-input-field')
        const searchInput = organizationField?.querySelector('input[type="text"]')
        if (searchInput) {
          searchInput.value = projectData.organization.name
          searchInput.dispatchEvent(new Event('change', { bubbles: true }))
          searchInput.dispatchEvent(new Event('input', { bubbles: true }))
        }
      }
  
      // Populate keywords (TomSelect)
      if (this.hasKeywordsTarget) {
        const select = this.keywordsTarget.querySelector('select')
        if (select) {
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
      }
  
      // Populate source hidden field if present
      const sourceField = document.getElementById('project_source')
      if (sourceField && projectData.source) {
        sourceField.value = projectData.source
      }
  
      // Set fields as readonly if funded
      const isFunded = localStorage.getItem('project_type') === 'funded'
      if (isFunded) {
        setTimeout(() => {
          if (this.hasAcronymTarget) this.makeFieldReadOnly(this.acronymTarget)
          if (this.hasGrantNumberTarget) this.makeFieldReadOnly(this.grantNumberTarget)
          if (this.hasFunderTarget) this.makeFieldReadOnly(this.funderTarget)
        }, 100)
      }
  
      localStorage.removeItem('selectedProjectData')
    } catch (error) {
      this.showErrorMessage("Error populating form: " + error.message)
    }
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
      
      const label = container.querySelector('label')
      if (label && !label.querySelector('.badge')) {
        const badge = document.createElement('span')
        badge.className = 'badge bg-secondary ms-2 small'
        badge.textContent = 'Auto-filled'
        label.appendChild(badge)
      }
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
      
      const label = container.querySelector('label')
      if (label) {
        const badge = label.querySelector('.badge')
        if (badge) badge.remove()
      }
    }
  }
  
  fillField(targetElement, value) {
    if (!value) return
    
    try {
      const input = targetElement.querySelector('input, textarea, select')
      if (input) {
        input.value = value
        input.dispatchEvent(new Event('change', { bubbles: true }))
        input.dispatchEvent(new Event('input', { bubbles: true }))
      }
    } catch (error) {}
  }
  
  fillDateField(targetElement, dateValue) {
    if (!dateValue) return
    
    try {
      const formattedDate = dateValue.includes('T') ? dateValue.split('T')[0] : dateValue
      
      const input = targetElement.querySelector('input[type="date"]')
      if (input) {
        input.value = formattedDate
        input.dispatchEvent(new Event('change', { bubbles: true }))
      }
    } catch (error) {}
  }

  updateLogoPreview() {
    const logoInput = this.element.querySelector('[data-project-creation-target="logoInput"]');
    if (!logoInput) return;
    
    const url = logoInput.value.trim();
    const previewImg = this.element.querySelector('[data-project-creation-target="logoPreview"]');
    const placeholder = this.element.querySelector('[data-project-creation-target="logoPlaceholder"]');
    
    if (!previewImg || !placeholder) return;
    
    if (url) {
      previewImg.src = url;
      
      previewImg.onload = () => {
        previewImg.classList.remove('d-none');
        placeholder.classList.add('d-none');
      };
      
      previewImg.onerror = () => {
        previewImg.classList.add('d-none');
        placeholder.classList.remove('d-none');
      };
    } else {
      previewImg.classList.add('d-none');
      placeholder.classList.remove('d-none');
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
  
  showErrorMessage(message) {
    const alertElement = document.createElement('div')
    alertElement.className = 'alert alert-danger alert-dismissible fade show'
    alertElement.innerHTML = `
      <div class="d-flex align-items-center">
        <i class="bi bi-exclamation-triangle-fill me-2"></i>
        <span>${message}</span>
      </div>
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    `
    
    const container = this.element.querySelector('.card-body')
    if (container) {
      container.insertBefore(alertElement, container.firstChild)
      
      setTimeout(() => {
        alertElement.classList.remove('show')
        setTimeout(() => alertElement.remove(), 150)
      }, 5000)
    }
  }
}