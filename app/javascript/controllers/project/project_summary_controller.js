import { Controller } from "@hotwired/stimulus"
import { UseModal } from "../../mixins/useModal"

export default class extends Controller {
    static values = {
        targetModal: { type: String, default: '#submissionModal' }
    }

    connect() {
        this.modal = new UseModal()
        this.boundHide = this.hide.bind(this)
        this.modal.onClose(this.element, this.boundHide)
        document.addEventListener('show-summary-modal', this.showSummaryManually.bind(this))
        document.addEventListener('shown.bs.modal', (event) => {
            if (event.target.id === 'submissionModal') this.populateSummary()
        })
        this.setupModalObserver()
    }

    setupModalObserver() {
        const modalElement = document.getElementById('submissionModal')
        if (!modalElement) return
        this.modalObserver = new MutationObserver(() => {
            if (modalElement.classList.contains('show')) setTimeout(() => this.populateSummary(), 50)
        })
        this.modalObserver.observe(modalElement, { attributes: true })
    }

    disconnect() {
        this.modal.onCloseRemoveEvent(this.element, this.boundHide)
        document.removeEventListener('show-summary-modal', this.showSummaryManually)
        if (this.modalObserver) this.modalObserver.disconnect()
    }

    showSummaryManually() {
        const modalElement = document.getElementById('submissionModal')
        if (!modalElement) return
        const bsModal = new bootstrap.Modal(modalElement)
        const onceShown = () => {
            this.populateSummary()
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
        const form = document.querySelector('form#new_project')
        if (form) form.requestSubmit()
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
        const truncate = (str, n = 50) => str.length > n ? str.slice(0, n) + "…" : str
    
        this.updateSummaryField('title', getByName('project[name]'))
        this.updateSummaryField('acronym', getByName('project[acronym]'))
        this.updateSummaryField('description', truncate(getByName('project[description]')))
        this.updateSummaryField('start-date', getByName('project[start_date]'))
        this.updateSummaryField('end-date', getByName('project[end_date]'))
        this.updateSummaryField('homepage', getByName('project[homePage]'))
        
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
    
        this.updateSummaryField('grant-number', getByName('project[grant_number]'))
    
        const contactChips = document.querySelectorAll('.contact-project-input-field .agent-chip-name')
        let contactValue = "/"
        if (contactChips.length > 0) {
            contactValue = Array.from(contactChips)
                .map(chip => chip.textContent.trim())
                .filter(Boolean)
                .join(', ')
        }
        this.updateSummaryField('contact', contactValue || "/")
    
        const orgChip = document.querySelector('.organization-project-input-field .agent-chip-name')
        this.updateSummaryField('organization', orgChip?.textContent.trim() || "/")
        
        const funderInput = document.querySelector('[name="project[funder]"], .funder-project-input-field input[type="text"]')
        this.updateSummaryField('funder', funderInput?.value.trim() || "/")
    
        const logoUrl = getByName('project[logo]')
        const logoImg = document.getElementById('summary-logo-img')
        if (logoImg) {
            logoImg.src = (logoUrl && logoUrl !== "/") ? logoUrl : "/"
            logoImg.style.display = (logoUrl && logoUrl !== "/") ? "inline-block" : "none"
        }
    
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

    updateSummaryField(id, value) {
        if (id === 'homepage') {
            const element = document.querySelector(`#summary-homepage`)
            if (element) {
                let displayValue = value && value !== "/" ? value : "/"
                if (displayValue.length > 15) {
                    displayValue = displayValue.slice(0, 15) + "..."
                }
                element.textContent = displayValue
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