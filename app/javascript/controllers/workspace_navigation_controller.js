import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "link"]

  connect() {
    this.sidebarTarget.scrollTop = Number(sessionStorage.getItem("workspace-sidebar-scroll") || 0)
    this.sync()
  }

  rememberScroll() {
    sessionStorage.setItem("workspace-sidebar-scroll", String(this.sidebarTarget.scrollTop))
  }

  loaded(event) {
    if (event.target.id !== "workspace_content") return
    this.sync()
    this.element.classList.remove("is-mobile-sidebar-open", "is-expanded")
  }

  sync() {
    const frame = this.element.querySelector("#workspace_content")
    if (!frame) return
    // Read the rendered page metadata, including on Back/Forward restoration.
    const page = frame.querySelector("[data-workspace-page]")
    const path = page?.dataset.workspacePage || frame.dataset.navigationPath
    this.linkTargets.forEach(link => {
      const active = new URL(link.href).pathname === path
      link.classList.toggle("is-active", active)
      if (active) link.setAttribute("aria-current", "page")
      else link.removeAttribute("aria-current")
    })
    document.title = page?.dataset.pageTitle || frame.dataset.pageTitle
  }
}
