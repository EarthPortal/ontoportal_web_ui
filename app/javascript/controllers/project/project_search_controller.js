import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loading", "errorContainer", "results", "resultsList", "resultsCount", "noResults", "projectIdInput", "searchTermInput"]
  static values = {
    api: String,
    datasetParam: String
  }
  
  connect() {
    this.selectedProject = null
    this.currentResults = []
  }

  apiValueChanged() {
    this.resetSearch()
  }
  
  handleIdKeypress(event) {
    if (event.key === 'Enter') {
      event.preventDefault()
      event.stopPropagation()
      this.searchById(event)
      return false
    }
  }

  handleTermKeypress(event) {
    if (event.key === 'Enter') {
      event.preventDefault()
      event.stopPropagation()
      this.searchByTerm(event)
      return false
    }
  }
  
  searchById(event) {
    event.preventDefault()
    const projectId = this.projectIdInputTarget.value.trim()
    
    if (!projectId) {
      this.showError("Please enter a valid project ID")
      return
    }
    
    this.performSearch(projectId, 'id')
  }
  
  searchByTerm(event) {
    event.preventDefault()
    const searchTerm = this.searchTermInputTarget.value.trim()
    
    if (!searchTerm || searchTerm.length < 2) {
      this.showError("Please enter a valid search term with at least 2 characters")
      return
    }
    
    this.performSearch(searchTerm, 'acronym')
  }

  getCurrentDataset() {
    if (this.datasetParamValue) {
      return this.datasetParamValue
    }
    
    const source = this.apiValue
    const datasetInput = document.querySelector(`input[name="${source}_dataset"]:checked`)
    return datasetInput ? datasetInput.value : ''
  }
  
  async performSearch(term, type) {
    this.resetSearch()
    this.showLoading()
    
    let source = this.apiValue
    const dataset = this.getCurrentDataset()
    if(dataset) source = dataset
    
    const params = new URLSearchParams()
    params.append('source', source)
    params.append('term', term)
    params.append('type', type)
    
    const url = `/projects/search_external?${params.toString()}`
    
    try {
      const response = await fetch(url, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (!response.ok) {
        throw new Error(`Server responded with status: ${response.status}`)
      }
      
      const data = await response.json()
      this.errorContainerTarget.classList.add("d-none")
      
      if (data.success) {
        const projects = data.results || []
        
        if (projects.length > 0) {
          this.displayResults(projects)
        } else {
          this.showNoResults()
        }
      } else {
        this.showError(data.message || "The search request failed")
      }
    } catch (error) {
      this.showError(`Error: ${error.message}`)
    } finally {
      this.hideLoading()
    }
  }
    
  showError(message) {
    if (!message) return
    
    this.errorContainerTarget.classList.remove("d-none")
    
    const alertElement = this.errorContainerTarget.querySelector('.alert-container')
    if (alertElement) {
      const messageElement = alertElement.querySelector('.alert-message')
      if (messageElement) {
        messageElement.innerHTML = message
      }
    }
    
    this.resultsTarget.classList.add("d-none")
    this.noResultsTarget.classList.add("d-none")
  }
  
  displayResults(projects) {
    if (!projects || projects.length === 0) {
      this.showNoResults()
      return
    }
    
    this.currentResults = projects
    
    this.resultsTarget.classList.remove('d-none')
    this.errorContainerTarget.classList.add('d-none')
    this.noResultsTarget.classList.add('d-none')
    
    this.resultsCountTarget.textContent = `(${projects.length})`
    this.resultsListTarget.innerHTML = ''
    
    projects.forEach(project => {
      try {
        const card = this.createProjectCard(project)
        this.resultsListTarget.appendChild(card)
      } catch (error) {}
    })
    
    this.resultsListTarget.style.opacity = '0'
    setTimeout(() => {
      this.resultsListTarget.style.transition = 'opacity 0.3s ease'
      this.resultsListTarget.style.opacity = '1'
    }, 50)
  }
  
  createProjectCard(project) {
    const card = document.createElement("div")
    card.className = "project-card p-3 border rounded"
    
    const projectId = project.id || project.acronym || project.grant_number || `project-${Math.random().toString(36).substring(2, 10)}`
    card.dataset.projectId = projectId
    
    card.addEventListener('click', this.selectProject.bind(this))
    
    const acronym = project.acronym || 'N/A'
    const grantNumber = project.grant_number || 'No ID'
    const fullName = project.name || 'Untitled Project'
    const name = fullName.length > 45 ? fullName.substring(0, 45) + '...' : fullName
    
    const safeHtml = `
      <div class="d-flex justify-content-between align-items-start">
        <div class="flex-grow-1">
          <div class="d-flex align-items-center mb-1">
            <h5 class="mb-0 me-2">${this.escapeHtml(acronym)}</h5>
            <span class="badge bg-light text-dark project-id">${this.escapeHtml(grantNumber)}</span>
          </div>
          <div class="project-title" title="${this.escapeHtml(fullName)}">${this.escapeHtml(name)}</div>
          <div class="meta-info small d-flex flex-wrap gap-1">
            ${project.coordinator ? `<span><i class="bi bi-person me-1"></i>${this.escapeHtml(project.coordinator)}</span>` : ''}
            ${project.start_date ? `<span><i class="bi bi-calendar me-1"></i>${this.escapeHtml(this.formatDates(project.start_date, project.end_date))}</span>` : ''}
          </div>
        </div>
      </div>
    `
    
    card.innerHTML = safeHtml
    return card
  }
  
  selectProject(event) {
    if (event.target.tagName === 'BUTTON' || event.target.closest('button') || 
        event.target.tagName === 'A' || event.target.closest('a')) {
      event.preventDefault()
    }
  
    const projectCard = event.target.closest('.project-card')
    if (!projectCard) return
  
    const projectId = projectCard.dataset.projectId
    if (!projectId) return
  
    document.querySelectorAll('.project-card').forEach(card => {
      card.classList.remove('selected')
    })
    projectCard.classList.add('selected')
  
    const projectData = this.findProjectById(projectId)
    if (!projectData) return
  
    const source = this.apiValue || this.datasetParamValue || ''
    const projectWithSource = { ...projectData, source }
  
    localStorage.setItem('selectedProjectData', JSON.stringify(projectWithSource))
  
    document.dispatchEvent(new CustomEvent('project-selected', {
      bubbles: true,
      detail: { projectData: projectWithSource }
    }))
  }

  findProjectById(id) {
    const results = this.currentResults || []
    
    if (!results || !Array.isArray(results)) {
      return null
    }
    
    return results.find(project => (
      (project.id && project.id.toString() === id) ||
      (project.acronym && project.acronym === id) ||
      (project.grant_number && project.grant_number === id)
    ))
  }
  
  filterResults(event) {
    const filterText = event.target.value.toLowerCase()
    const cards = this.resultsListTarget.querySelectorAll('.project-card')
    
    let visibleCount = 0
    
    cards.forEach(card => {
      const title = card.querySelector('.project-title')?.textContent.toLowerCase() || ''
      const desc = card.querySelector('.project-description')?.textContent.toLowerCase() || ''
      const id = card.querySelector('.project-id')?.textContent.toLowerCase() || ''
      
      if (title.includes(filterText) || desc.includes(filterText) || id.includes(filterText)) {
        card.style.display = ''
        visibleCount++
      } else {
        card.style.display = 'none'
      }
    })
    
    this.resultsCountTarget.textContent = `(${visibleCount})`
    
    if (visibleCount === 0) {
      this.noResultsTarget.classList.remove('d-none')
    } else {
      this.noResultsTarget.classList.add('d-none')
    }
  }
  
  clearFilter(event) {
    const filterInput = event.target.closest('.input-group').querySelector('input')
    filterInput.value = ''
    
    const cards = this.resultsListTarget.querySelectorAll('.project-card')
    cards.forEach(card => card.style.display = '')
    
    this.resultsCountTarget.textContent = `(${cards.length})`
    this.noResultsTarget.classList.add('d-none')
  }
  
  showLoading() {
    this.loadingTarget.classList.remove("d-none")
  }
  
  hideLoading() {
    this.loadingTarget.classList.add("d-none")
  }
  
  resetSearch() {
    this.resultsTarget.classList.add("d-none")
    this.noResultsTarget.classList.add("d-none")
    
    if (this.hasErrorContainerTarget) {
      this.errorContainerTarget.classList.add("d-none")
      
      const alertElement = this.errorContainerTarget.querySelector('.alert')
      if (alertElement) {
        const messageElement = alertElement.querySelector('.alert-message')
        if (messageElement) {
          messageElement.textContent = ""
        }
      }
    }
    
    this.resultsListTarget.innerHTML = ''
    this.resultsCountTarget.textContent = ''
    this.selectedProject = null
    this.currentResults = []
  }
    
  showNoResults() {
    this.resultsTarget.classList.remove("d-none")
    this.noResultsTarget.classList.remove("d-none")
    this.errorContainerTarget.classList.add("d-none")
    this.resultsCountTarget.textContent = '(0)'
  }
  
  formatDates(start, end) {
    if (!start) return ''
    
    try {
      const startDate = new Date(start)
      let result = startDate.toLocaleDateString()
      
      if (end) {
        const endDate = new Date(end)
        result += ` - ${endDate.toLocaleDateString()}`
      }
      
      return result
    } catch (e) {
      return start + (end ? ` - ${end}` : '')
    }
  }
  
  escapeHtml(unsafe) {
    if (!unsafe) return ''
    return String(unsafe)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;")
  }
}