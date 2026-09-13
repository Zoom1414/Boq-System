import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "worksheet", "category", "noResults", "importDialog"]
  navigate(event) { event.target.form.requestSubmit() }
  toggleSidebar() {
    this.element.classList.toggle(window.innerWidth < 900 ? "is-mobile-sidebar-open" : "is-sidebar-collapsed")
  }
  toggleFullscreen() { this.element.classList.toggle("is-expanded") }
  worksheetTargetConnected() { if (this.hasSearchTarget) this.filter() }
  filter() {
    const query = this.searchTarget.value.trim().toLocaleLowerCase()
    let matches = 0
    this.categoryTargets.forEach(group => {
      let count = 0
      group.querySelectorAll("[data-item-row]").forEach(row => {
        const visible = !query || row.dataset.search.includes(query)
        row.hidden = !visible || (!query && group.dataset.collapsed === "true")
        if (visible) count++
      })
      group.hidden = !!query && count === 0 && !group.dataset.categoryName.toLocaleLowerCase().includes(query)
      group.querySelectorAll("[data-empty-category]").forEach(row => { row.hidden = group.dataset.collapsed === "true" })
      matches += count
    })
    if (this.hasNoResultsTarget) this.noResultsTarget.hidden = !query || matches > 0
  }
  toggleCategory(event) {
    const group = event.currentTarget.closest("tbody")
    this.setCollapsed(group, group.dataset.collapsed !== "true")
    this.filter()
  }
  setCollapsed(group, collapsed) {
    group.dataset.collapsed = String(collapsed)
    group.querySelector("button").setAttribute("aria-expanded", String(!collapsed))
    group.querySelector("[data-chevron]").textContent = collapsed ? "›" : "⌄"
  }
  collapseAll() { this.searchTarget.value = ""; this.categoryTargets.forEach(g => this.setCollapsed(g, true)); this.filter() }
  expandAll() { this.searchTarget.value = ""; this.categoryTargets.forEach(g => this.setCollapsed(g, false)); this.filter() }
  jump(event) {
    const group = this.categoryTargets.find(g => g.id === event.target.value)
    if (!group) return
    this.searchTarget.value = ""; this.setCollapsed(group, false); this.filter()
    group.scrollIntoView({behavior: "smooth", block: "center"})
  }
  openImport() { this.importDialogTarget.showModal() }
  closeImport() { this.importDialogTarget.close() }
}
