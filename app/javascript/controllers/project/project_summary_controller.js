import { Controller } from "@hotwired/stimulus"
import { UseModal } from "../../mixins/useModal"

export default class extends Controller {
    static values = {
        targetModal: { type: String, default: '#submissionModal' }
    }

    connect() {
        this.modal = new UseModal()
        this.boundHide = this.hide.bind(this)
        this.boundShowSummaryManually = this.showSummaryManually.bind(this)
        
        this.modal.onClose(this.element, this.boundHide)
        document.addEventListener('show-summary-modal', this.boundShowSummaryManually)
        document.addEventListener('shown.bs.modal', this.handleModalShown.bind(this))
        
        this.setupModalObserver()
    }

    handleModalShown(event) {
        if (event.target.id === 'submissionModal') {
            this.populateSummary()
            this.validateRequiredFields()
        }
    }

    setupModalObserver() {
        const modalElement = document.getElementById('submissionModal')
        if (!modalElement) return
        
        this.modalObserver = new MutationObserver(() => {
            if (modalElement.classList.contains('show')) {
                setTimeout(() => {
                    this.populateSummary()
                    this.validateRequiredFields()
                }, 50)
            }
        })
        
        this.modalObserver.observe(modalElement, { attributes: true })
    }

    disconnect() {
        this.modal.onCloseRemoveEvent(this.element, this.boundHide)
        document.removeEventListener('show-summary-modal', this.boundShowSummaryManually)
        
        if (this.modalObserver) {
            this.modalObserver.disconnect()
        }
    }

    showSummaryManually() {
        const modalElement = document.getElementById('submissionModal')
        if (!modalElement) return
        
        const bsModal = new bootstrap.Modal(modalElement)
        const onceShown = () => {
            this.populateSummary()
            this.validateRequiredFields()
            modalElement.removeEventListener('shown.bs.modal', onceShown)
        }
        
        modalElement.addEventListener('shown.bs.modal', onceShown)
        bsModal.show()
    }

    cancel(event) {
        event.preventDefault()
        this.hide()
    }

    confirm(event) {
        event.preventDefault()
        
        if (this.validateRequiredFields()) {
            const form = document.querySelector('form#new_project')
            if (form) form.requestSubmit()
        }
    }

    hide() {
        const target = document.querySelector(this.targetModalValue)
        if (target) this.modal.hideModal(target)
    }

    populateSummary() {
        const getByName = (name) => {
            const el = document.querySelector(`[name="${name}"]`)
            return el ? (el.value?.trim() ? el.value : "/") : "/"
        }
        
        this.updateSummaryField('title', getByName('project[name]'))
        this.updateSummaryField('acronym', getByName('project[acronym]'))
        this.updateSummaryField('description', getByName('project[description]'))
        this.updateSummaryField('start-date', getByName('project[start_date]'))
        this.updateSummaryField('end-date', getByName('project[end_date]'))
        this.updateSummaryField('homepage', getByName('project[homePage]'))
        this.updateSummaryField('grant-number', getByName('project[grant_number]'))
        
        this.updateKeywordsField()
        this.updateContactField()
        this.updateOrganizationField()
        this.updateFunderField()
        this.updateLogoDisplay()
        this.updateOntologiesList()
    }
    
    updateKeywordsField() {
        const keywordsSelect = document.querySelector('[name="project[keywords][]"]')
        let keywordsValue = "/"
        
        if (keywordsSelect) {
            if (keywordsSelect.selectedOptions?.length > 0) {
                keywordsValue = Array.from(keywordsSelect.selectedOptions)
                    .map(opt => opt.textContent.trim())
                    .filter(Boolean)
                    .join(', ')
            } else if (keywordsSelect.value) {
                keywordsValue = keywordsSelect.value
            }
        }
        
        this.updateSummaryField('keywords', keywordsValue)
    }
    
    updateContactField() {
        const contactChips = document.querySelectorAll('.contact-project-input-field .agent-chip-name')
        let contactValue = "/"
        
        if (contactChips.length > 0) {
            contactValue = Array.from(contactChips)
                .map(chip => chip.textContent.trim())
                .filter(Boolean)
                .join(', ')
        }
        
        this.updateSummaryField('contact', contactValue || "/")
    }
    
    updateOrganizationField() {
        const orgChip = document.querySelector('.organization-project-input-field .agent-chip-name')
        this.updateSummaryField('organization', orgChip?.textContent.trim() || "/")
    }
    
    updateFunderField() {
        const funderDisplayInput = document.querySelector('input[name="project_funder_display"]')
        if (funderDisplayInput?.value.trim()) {
            this.updateSummaryField('funder', funderDisplayInput.value.trim())
        }
    }
    
    updateLogoDisplay() {
        const logoUrl = document.querySelector('[name="project[logo]"]')?.value.trim()
        const logoImg = document.getElementById('summary-logo-img')
        
        if (logoImg) {
            logoImg.src = (logoUrl && logoUrl !== "/") ? logoUrl : "/"
            logoImg.style.display = (logoUrl && logoUrl !== "/") ? "inline-block" : "none"
        }
    }
    
    updateOntologiesList() {
        const ontologySelect = document.querySelector('[name="project[ontologyUsed][]"], #project_ontologies')
        let ontologiesHtml = '<li class="text-muted">/</li>'
        
        if (ontologySelect?.selectedOptions?.length > 0) {
            ontologiesHtml = Array.from(ontologySelect.selectedOptions)
                .map(option => `<li>${option.textContent}</li>`)
                .join('')
        }
        
        const ontologiesElement = document.querySelector('#summary-ontologies')
        if (ontologiesElement) ontologiesElement.innerHTML = ontologiesHtml
    }

    validateRequiredFields() {
    const requiredFields = [
        { name: 'project[name]', display: 'Project Title', summaryId: 'title', errorId: 'title-error' },
        { name: 'project[acronym]', display: 'Project Acronym', summaryId: 'acronym', errorId: 'acronym-error' },
        { name: 'project[description]', display: 'Project Description', summaryId: 'description', errorId: 'description-error' },
        { name: 'project[homePage]', display: 'Homepage', summaryId: 'homepage', errorId: 'homepage-error' }
    ]
    
    const ontologySelect = document.querySelector('[name="project[ontologyUsed][]"], #project_ontologies')
    const ontologiesSelected = ontologySelect?.selectedOptions?.length > 0
    
    const keywordsSelect = document.querySelector('[name="project[keywords][]"]')
    const keywordsSelected = keywordsSelect?.selectedOptions?.length > 0 || 
                            (keywordsSelect?.value && keywordsSelect.value.trim() !== '')
    
    this.clearValidationWarnings()
    
    const missingFields = []
    let hasErrors = false
    
    requiredFields.forEach(field => {
        const el = document.querySelector(`[name="${field.name}"]`)
        const value = el ? el.value?.trim() : ''
        
        if (!value) {
            missingFields.push(field)
            this.showFieldError(field.summaryId, field.errorId)
            hasErrors = true
        } else if (field.name === 'project[acronym]') {
            const acronymErrors = this.validateAcronym(value)
            if (acronymErrors.length > 0) {
                acronymErrors.forEach(error => {
                    this.showFieldError('acronym', `acronym-${error[0]}-error`)
                })
                hasErrors = true
            }
        }
    })
    
    if (!ontologiesSelected) {
        missingFields.push({ display: 'Ontologies', errorId: 'ontologies-error' })
        this.showFieldError('ontologies', 'ontologies-error')
        hasErrors = true
    }
    
    if (!keywordsSelected) {
        missingFields.push({ display: 'Keywords', errorId: 'keywords-error' })
        this.showFieldError('keywords', 'keywords-error')
        hasErrors = true
    }
    

    const startDateInput = document.querySelector('[name="project[start_date]"]')
    const endDateInput = document.querySelector('[name="project[end_date]"]')
    
    if (startDateInput?.value && endDateInput?.value) {
        const startDate = new Date(startDateInput.value)
        const endDate = new Date(endDateInput.value)
    
        if (startDate > endDate) {
            this.showFieldError('end-date', 'date-range-error')
            hasErrors = true
        }
    }


    const homepageInput = document.querySelector('[name="project[homePage]"]');
    if (homepageInput?.value?.trim() && homepageInput.value !== '/') {
        if (!this.validateUri(homepageInput.value.trim())) {
            this.showFieldError('homepage', 'homepage-uri-error');
            hasErrors = true;
        }
    }

    if (hasErrors) {
        this.showValidationAlert()
        
        const confirmBtn = document.querySelector('#submit-project-btn')
        if (confirmBtn) {
            confirmBtn.disabled = true
        }
    }
    
    return !hasErrors
}
    
    showFieldError(summaryId, errorId) {
        const summaryEl = document.querySelector(`#summary-${summaryId}`)
        if (summaryEl) {
            summaryEl.classList.add('text-danger')
        }
        
        const errorEl = document.querySelector(`#${errorId}`)
        if (errorEl) {
            errorEl.classList.remove('d-none')
        }
    }
    
    showValidationAlert() {
        const alertContainer = document.querySelector('#validation-alert-container')
        if (alertContainer) {
            alertContainer.classList.remove('d-none')
        }
    }
    
    clearValidationWarnings() {
        const alertContainer = document.querySelector('#validation-alert-container')
        if (alertContainer) {
            alertContainer.classList.add('d-none')
        }
        
        const errorMessages = document.querySelectorAll('.invalid-feedback')
        errorMessages.forEach(el => {
            el.classList.add('d-none')
        })
        
        const highlightedElements = document.querySelectorAll('.text-danger')
        highlightedElements.forEach(el => {
            el.classList.remove('text-danger')
        })
        
        const confirmBtn = document.querySelector('#submit-project-btn')
        if (confirmBtn) {
            confirmBtn.disabled = false
        }
    }    

    validateUri(uri) {
        if (!uri || uri === '/') return true;
        
        if (!uri.match(/^https:\/\//)) {
            return false;
        }
        if (uri === 'https://' || uri.match(/^https:\/\/\s*$/)) {
            return false;
        }

        try {
            const url = new URL(uri);
            return url.hostname && url.hostname.length > 0;
        } catch (e) {
            return false;
        }
    }

    validateAcronym(acronym) {
    const errors = []
    
    if (!acronym.match(/^[a-zA-Z]/)) {
        errors.push(['start-letter'])
    }
    
    if (acronym.match(/[a-z]/)) {
        errors.push(['capital-letters'])
    }
    
    if (acronym.match(/[^-_0-9a-zA-Z]/)) {
        errors.push(['special-chars'])
    }
    
    if (acronym.length > 16) {
        errors.push(['length'])
    }
    
    return errors
}

    updateSummaryField(id, value) {
        if (id === 'homepage') {
            const element = document.querySelector(`#summary-homepage`)
            if (element) {
                element.textContent = value
                element.href = (value && value !== "/" ? value : "#")
                element.target = "_blank"
            }
            return
        }
        
        const element = document.querySelector(`#summary-${id}`) ||
                        document.querySelector(`[id="summary-${id}"]`) ||
                        document.querySelector(`[data-summary-id="${id}"]`)
        if (element) {
            element.textContent = value
        }
    }
}