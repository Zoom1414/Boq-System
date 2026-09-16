import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "loading"]

  connect() {
    this.drafts = new Map()
    this.current = this.selectTarget.value
  }
  change() {
    const form = document.querySelector("#labor-items .labor-form")
    if (form) {
      const amounts = [...form.querySelectorAll("input[data-amount]")].map(input => [input.id, input.value])
      this.drafts.set(this.current, { amounts, date: form.querySelector("input[type=date]")?.value,
        key: form.querySelector("input[name$='[submission_key]']")?.value })
    }
    this.current = this.selectTarget.value
    this.loadingTarget.hidden = false
    this.element.requestSubmit()
  }
  loaded(event) {
    if (event.target.id !== "labor-items") return
    this.loadingTarget.hidden = true
    const values = this.drafts.get(this.current)
    if (!values) return
    const form = event.target.querySelector(".labor-form")
    if (!form) return
    const inputs = [...form.querySelectorAll("input[data-amount]")]
    values.amounts.forEach(([id, value]) => {
      const input = inputs.find(input => input.id === id)
      if (input) input.value = value
    })
    if (values.date) form.querySelector("input[type=date]").value = values.date
    if (values.key) form.querySelector("input[name$='[submission_key]']").value = values.key
    form.dispatchEvent(new Event("input", { bubbles: true }))
  }
  saved(event) {
    const stream = event.target
    if (stream.getAttribute("target") === "finance-form" && stream.querySelector("template")?.content.querySelector(".finance-success")) {
      this.drafts.delete(this.current)
    }
  }
}
