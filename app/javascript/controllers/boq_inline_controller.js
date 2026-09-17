import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Admin inline editing for the Master BOQ worksheet.
// Each row saves through PATCH (turbo-stream); saves for the same row run one at a time
// so the lock_version returned by the previous save is used by the next one.
export default class extends Controller {
  connect() { this.queues = new Map() }

  save(event) {
    const input = event.target
    const row = input.closest("tr[data-url]")
    if (!row || String(input.value) === String(input.dataset.original ?? "")) return
    if (input.dataset.pending === input.value) return // Enter already queued this value
    input.dataset.pending = input.value
    const previous = this.queues.get(row.id) || Promise.resolve()
    const next = previous.then(() => this.submit(row, input)).catch(() => {})
    this.queues.set(row.id, next)
  }

  async submit(row, input) {
    const current = document.getElementById(row.id) || row
    const body = new FormData()
    current.querySelectorAll("[data-inline-field]").forEach(field => body.append(field.name, field.value))
    body.append("_method", "patch")
    body.append("inline", "1")
    body.append("row_number", current.dataset.rowNumber)
    current.classList.remove("is-saved", "is-error")
    current.classList.add("is-saving")
    try {
      const response = await fetch(current.dataset.url, {
        method: "POST", body, credentials: "same-origin",
        headers: { Accept: "text/vnd.turbo-stream.html", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content }
      })
      const html = await response.text()
      if (html.includes("<turbo-stream")) Turbo.renderStreamMessage(html)
      const updated = document.getElementById(row.id)
      if (response.ok) {
        const field = updated?.querySelector(`#${CSS.escape(input.id)}`)
        if (field) field.dataset.original = field.value
        updated?.classList.add("is-saved")
        setTimeout(() => updated?.classList.remove("is-saved"), 1200)
      } else {
        updated?.classList.add("is-error")
      }
    } catch (error) {
      this.status("บันทึกไม่สำเร็จ ตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง", true)
      current.classList.add("is-error")
    } finally {
      document.getElementById(row.id)?.classList.remove("is-saving")
      const field = document.getElementById(input.id)
      if (field) delete field.dataset.pending
    }
  }

  key(event) {
    const input = event.target
    if (event.key === "Escape") {
      input.value = input.dataset.original ?? ""
      input.blur()
    } else if (event.key === "Enter" && input.tagName !== "SELECT") {
      event.preventDefault()
      input.dispatchEvent(new Event("change", { bubbles: true }))
      const field = input.id.split("-").slice(3).join("-")
      const rows = [...this.element.querySelectorAll("tr[data-url]")].filter(r => !r.hidden)
      const index = rows.findIndex(r => r.id === input.closest("tr").id)
      const target = rows[index + (event.shiftKey ? -1 : 1)]?.querySelector(`[id$='-${field}']`)
      if (target) { target.focus(); target.select?.() } else input.blur()
    }
  }

  status(message, error = false) {
    const el = document.getElementById("boq-inline-status")
    if (!el) return
    el.textContent = message
    el.classList.toggle("is-error", error)
  }
}
