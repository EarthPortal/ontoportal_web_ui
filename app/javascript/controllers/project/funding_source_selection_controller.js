import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sourceRadio", "datasetContainer", "searchTitle", "searchComponent"]
  
  connect() {
    this.element.addEventListener('dataset-changed', this.handleDatasetChanged.bind(this))
    this.setDefaultSource()
  }
  
  disconnect() {
    this.element.removeEventListener('dataset-changed', this.handleDatasetChanged.bind(this))
  }
  
  setDefaultSource() {
    const defaultSourceId = 'cordis'
    const radioButton = this.sourceRadioTargets.find(radio => radio.value === defaultSourceId)
    if (radioButton) {
      radioButton.checked = true
      this._updateFundingSourceUI(defaultSourceId)
      if (this.hasSearchComponentTarget) {
        const defaultDataset = this._getDefaultDatasetForSource(defaultSourceId)
        this.searchComponentTarget.setAttribute('data-project-search-api-value', defaultSourceId)
        this.searchComponentTarget.setAttribute('data-project-search-dataset-param-value', defaultDataset)
      }
    }
  }
  
  handleDatasetChanged(event) {
    const { datasetId } = event.detail
    if (this.hasSearchComponentTarget) {
      this.searchComponentTarget.setAttribute('data-project-search-dataset-param-value', datasetId)
    }
  }
  
  toggleSource(event) {
    const sourceId = event.target.value
    this._updateFundingSourceUI(sourceId)
    if (this.hasSearchComponentTarget) {
      const defaultDataset = this._getDefaultDatasetForSource(sourceId)
      this.searchComponentTarget.setAttribute('data-project-search-dataset-param-value', defaultDataset)
    }
  }
  
  selectSourceFromBlock(event) {
    if (event.target.closest('.dataset-container') || event.target.closest('.form-check-input')) return
    
    const sourceBlock = event.currentTarget
    const sourceId = sourceBlock.dataset.sourceId
    const radioButton = this.sourceRadioTargets.find(radio => radio.value === sourceId)
    
    if (radioButton && !radioButton.checked) {
      radioButton.checked = true
      this._updateFundingSourceUI(sourceId)
      if (this.hasSearchComponentTarget) {
        const defaultDataset = this._getDefaultDatasetForSource(sourceId)
        this.searchComponentTarget.setAttribute('data-project-search-dataset-param-value', defaultDataset)
      }
    }
  }
  
  _getDefaultDatasetForSource(sourceId) {
    const container = this.datasetContainerTargets.find(c => c.dataset.sourceId === sourceId)
    if (container) {
      const defaultInput = container.querySelector(`input[name="${sourceId}_dataset"]:checked`)
      if (defaultInput) return defaultInput.value
    }
    return ''
  }
  
  _updateFundingSourceUI(sourceId) {
    document.querySelectorAll('.funding-source-option').forEach(option => {
      option.setAttribute('data-funding-selected', option.dataset.sourceId === sourceId ? 'true' : 'false')
    })
    
    this.datasetContainerTargets.forEach(container => {
      container.classList.toggle('d-none', container.dataset.sourceId !== sourceId)
    })
    
    if (this.hasSearchComponentTarget) {
      this.searchComponentTarget.setAttribute('data-project-search-api-value', sourceId)
    }
    
    if (this.hasSearchTitleTarget) {
      const titleKey = `projects.project_search.${sourceId}_title`
      const translation = this._getTranslation(titleKey)
      this.searchTitleTarget.textContent = translation !== titleKey 
        ? translation : `${sourceId.toUpperCase()} Project Search`
    }
  }
  
  _getTranslation(key) {
    if (typeof I18n !== 'undefined') return I18n.t(key)
    const translationElement = document.querySelector(`[data-i18n-key="${key}"]`)
    return translationElement ? translationElement.textContent : key
  }
}