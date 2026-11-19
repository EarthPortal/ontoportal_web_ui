import { Controller } from "@hotwired/stimulus"
import DataTable from 'datatables.net-dt'

// Type and Curation filters of the Curation tab of the administration console (admin/curation/index.html.haml).
// The rows are hidden by the DataTables search itself, so the filters, the search box and the sort work together.
const TABLE_ID = 'admin_curation'

DataTable.ext.search.push((settings, _searchData, rowIndex) => {
  if (settings.nTable.id !== TABLE_ID) return true

  const row = settings.aoData[rowIndex].nTr
  const type = document.getElementById('select_curation_type')?.value || 'all'
  const curation = document.getElementById('select_curation_state')?.value || 'all'
  return (type === 'all' || row.dataset.type === type) &&
    (curation === 'all' || row.dataset.curation === curation)
})

// Connects to data-controller="curation-filters"
export default class extends Controller {
  static targets = ['count']
  // "N shown" text, with __COUNT__ in place of the number
  static values = { shown: String }

  connect() {
    this.onDraw = () => this.#updateCount()
    // The table is turned into a DataTable by its own controller (table-component), maybe after this one connects
    this.#whenTableReady(api => {
      api.on('draw', this.onDraw)
      api.draw()
    })
  }

  disconnect() {
    this.#api()?.off('draw', this.onDraw)
  }

  filter() {
    this.#api()?.draw()
  }

  #api() {
    const table = document.getElementById(TABLE_ID)
    return table && DataTable.isDataTable(table) ? DataTable.Api(table) : null
  }

  #whenTableReady(callback, tries = 40) {
    const api = this.#api()
    if (api) {
      callback(api)
    } else if (tries > 0) {
      setTimeout(() => this.#whenTableReady(callback, tries - 1), 50)
    }
  }

  #updateCount() {
    const api = this.#api()
    if (api && this.hasCountTarget) {
      this.countTarget.textContent = this.shownValue.replace('__COUNT__', api.rows({ search: 'applied' }).count())
    }
  }
}
