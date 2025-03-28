import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "projectData", "name", "acronym", "description", 
    "startDate", "endDate", "organization", "contact", 
    "homePage", "keywords", "grantNumber", "funder",
    "fundedRadio", "notFundedRadio", "fundingSourceRadio", 
    "isFunded", "fundingSource", "steps", "progressBar", "progressItem"
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
    
    const urlParams = new URLSearchParams(window.location.search)
    this.currentStepValue = parseInt(urlParams.get('step') || 1)
    
    document.addEventListener("project-selected", this.handleProjectSelection.bind(this))
    document.addEventListener("skip-to-step", this.handleSkipToStep.bind(this))
    document.addEventListener('project-selected', this.handleProjectSelected.bind(this))
    
    if (this.element) {
      this.element.addEventListener('populate-project-form', this.populateProjectForm.bind(this))
    }
    
    this.updateStepsVisibility()
    this.updateProgressUI()
    
    setTimeout(() => this.populateProjectForm(), 300)
  }
  
  disconnect() {
    document.removeEventListener("project-selected", this.handleProjectSelection.bind(this))
    document.removeEventListener("skip-to-step", this.handleSkipToStep.bind(this))
    document.removeEventListener('project-selected', this.handleProjectSelected.bind(this))
    
    if (this.element) {
      this.element.removeEventListener('populate-project-form', this.populateProjectForm.bind(this))
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
    if (!event.detail || !event.detail.projectData) return
    
    const projectData = event.detail.projectData
    
    if (this.hasProjectDataTarget) {
      this.projectDataTarget.value = JSON.stringify(projectData)
    }
    
    this.storeSelectedProject(projectData)
  }
  
  handleProjectSelected(event) {
    if (!event.detail || !event.detail.projectData) return
    
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
      
      if (this.hasNameTarget) {
        this.fillField(this.nameTarget, projectData.name || projectData.title)
      }
      
      if (this.hasAcronymTarget) {
        this.fillField(this.acronymTarget, projectData.acronym)
      }
      
      if (this.hasDescriptionTarget) {
        this.fillField(this.descriptionTarget, projectData.description)
      }
      
      if (this.hasStartDateTarget && projectData.start_date) {
        this.fillDateField(this.startDateTarget, projectData.start_date)
      }
      
      if (this.hasEndDateTarget && projectData.end_date) {
        this.fillDateField(this.endDateTarget, projectData.end_date)
      }
      
      if (this.hasOrganizationTarget) {
        this.fillField(this.organizationTarget, 
          projectData.organization || projectData.organisation || projectData.institution)
      }
      
      if (this.hasContactTarget) {
        this.fillField(this.contactTarget, projectData.contact || projectData.coordinator)
      }
      
      if (this.hasHomePageTarget) {
        this.fillField(this.homePageTarget, projectData.homePage || projectData.homepage)
      }
      
      if (this.hasKeywordsTarget && projectData.keywords) {
        this.fillField(this.keywordsTarget, projectData.keywords)
      }
      
      if (this.hasGrantNumberTarget) {
        this.fillField(this.grantNumberTarget, projectData.grant_number || "")
      }
      
      if (this.hasFunderTarget) {
        let funderValue = projectData.funder || ""
        if (typeof funderValue === 'object' && funderValue.name) {
          funderValue = funderValue.name
        }
        this.fillField(this.funderTarget, funderValue)
      }
      
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
      let formattedDate = dateValue
      
      if (dateValue.includes('T')) {
        formattedDate = dateValue.split('T')[0]
      }
      
      const input = targetElement.querySelector('input[type="date"]')
      if (input) {
        input.value = formattedDate
        input.dispatchEvent(new Event('change', { bubbles: true }))
      }
    } catch (error) {}
  }
  
  handleSkipToStep(event) {
    if (!event.detail || !event.detail.step) return
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
        const stepNumber = index + 1
        step.classList.toggle('d-none', stepNumber !== this.currentStepValue)
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
      const totalSteps = this.progressItemTargets ? this.progressItemTargets.length : 4
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