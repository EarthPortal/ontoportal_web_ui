import { Controller } from "@hotwired/stimulus"
import { UseModal } from "../mixins/useModal"

export default class extends Controller {
    static targets = ['modal']
    static values = {
        targetModal: { type: String, default: '#submissionModal' },
    }

    connect() {
        this.modal = new UseModal()
        this.boundHide = this.hide.bind(this)
        this.modal.onClose(this.element, this.boundHide)
    }

    disconnect() {
        this.modal.onCloseRemoveEvent(this.element, this.boundHide)
    }

    cancel(event) {
        event.preventDefault()
        this.hide()
        console.log("Cancel button clicked")
    }

    confirm(event) {
        event.preventDefault()
        this.hide()
        
        const form = document.getElementById('ontologyForm')
        if (form) {
            form.submit()
        }
        console.log("Confirm button clicked")
    }

    hide() {
        let target = this.targetModalElement
        if (target) {
            this.modal.hideModal(target)
        }
    }

    get targetModalElement() {
        return document.querySelector(this.targetModalValue)
    }
}