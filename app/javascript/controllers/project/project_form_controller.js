import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["title", "acronym", "description", "startDate", "endDate", 
                   "organization", "contact", "homePage", "keywords", 
                   "grantNumber", "funder"]
  
  connect() {
    document.addEventListener("project-selection", this.fillFormWithProject.bind(this))
    document.addEventListener("funding-source-selected", this.updateFundingSection.bind(this))
    document.addEventListener("project-type-selected", this.handleProjectTypeSelection.bind(this))
  }
  
  disconnect() {
    document.removeEventListener("project-selection", this.fillFormWithProject.bind(this))
    document.removeEventListener("funding-source-selected", this.updateFundingSection.bind(this))
    document.removeEventListener("project-type-selected", this.handleProjectTypeSelection.bind(this))
  }
  
  fillFormWithProject(event) {
    const project = event.detail.project
    
    this.setInputValue(this.titleTarget, project.name || project.title || "")
    this.setInputValue(this.acronymTarget, project.acronym || "", true)
    this.setInputValue(this.descriptionTarget, project.description || "")
    this.setInputValue(this.startDateTarget, this.formatDate(project.start_date))
    this.setInputValue(this.endDateTarget, this.formatDate(project.end_date))
    this.setInputValue(this.organizationTarget, project.organization.name || "")
    this.setInputValue(this.contactTarget, project.coordinator || project.contact || "")
    this.setInputValue(this.homePageTarget, project.homepage || project.homePage || "")
    
    if (Array.isArray(project.keywords)) {
      this.setInputValue(this.keywordsTarget, project.keywords.join(", "))
    } else {
      this.setInputValue(this.keywordsTarget, project.keywords || "")
    }
    
    this.setInputValue(this.grantNumberTarget, project.grant_number || project.grantNumber || "", true)
    this.setInputValue(this.funderTarget, project.funder || project.fundingSource || "", true)
    
    this.makeFieldReadonly(this.acronymTarget);
    this.makeFieldReadonly(this.grantNumberTarget);
    this.makeFieldReadonly(this.funderTarget);
  }
  
  makeFieldReadonly(container) {
    const inputs = container.querySelectorAll('input, textarea, select');
    inputs.forEach(input => {
      input.setAttribute('readonly', 'readonly');
      input.readOnly = true;
      input.classList.add('bg-light');
      
      const formGroup = input.closest('.form-group, .upload-ontology-input-field-container');
      if (formGroup) {
        const label = formGroup.querySelector('label');
        if (label && !label.querySelector('.badge')) {
          const badge = document.createElement('span');
          badge.className = 'badge bg-secondary ms-2 small';
          badge.textContent = 'Auto-filled';
          label.appendChild(badge);
        }
      }
    });
  }
  
  setInputValue(container, value, readonly = false) {
    const inputs = container.querySelectorAll('input, textarea, select');
    
    inputs.forEach(input => {
      input.value = value;
      
      if (readonly) {
        input.setAttribute('readonly', 'readonly');
        input.readOnly = true;
        input.classList.add('bg-light');
      }
    });
  }
  
  formatDate(dateString) {
    if (!dateString) return "";
    try {
      const date = new Date(dateString);
      return date.toISOString().split('T')[0];
    } catch (e) {
      return "";
    }
  }
  
  handleProjectTypeSelection() {
    // Placeholder for future functionality
  }
  
  updateFundingSection() {
    // Placeholder for future functionality
  }
}