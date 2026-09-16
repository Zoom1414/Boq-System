import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "search", "noMatches", "warning", "override", "reason", "count", "total", "submit", "clear", "selectionHint"]
  static values = { admin: Boolean }

  connect() { this.calculate() }
  money(value) { return Number(value).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 }) }
  fillRemaining(event) {
    const row = event.currentTarget.closest("[data-remaining]")
    row.querySelector("[data-amount]").value = Math.max(0, Number(row.dataset.remaining)).toFixed(2)
    this.calculate()
  }
  clear() { this.rowTargets.forEach(row => { row.querySelector("[data-amount]").value = "" }); this.calculate() }
  filter() {
    const query = this.searchTarget.value.trim().toLocaleLowerCase()
    this.rowTargets.forEach(row => { row.hidden = !row.dataset.search.includes(query) })
    this.noMatchesTarget.hidden = this.rowTargets.some(row => !row.hidden)
    this.calculate()
  }
  calculate() {
    let total = 0, count = 0, exceeded = false, invalid = false, hiddenCount = 0
    this.rowTargets.forEach(row => {
      const input = row.querySelector("[data-amount]")
      const amount = Number(input.value || 0), remaining = Number(row.dataset.remaining) - amount
      invalid ||= !input.validity.valid || !Number.isFinite(amount) || amount < 0
      if (Number.isFinite(amount) && amount > 0) { total += amount; count++; if (row.hidden) hiddenCount++ }
      const over = amount > 0 && remaining < 0
      exceeded ||= over
      row.classList.toggle("has-amount", amount > 0)
      row.classList.toggle("is-over-budget", over)
      row.querySelector("[data-after]").textContent = this.money(remaining)
      row.querySelector("[data-line-warning]").hidden = !over
    })
    this.countTarget.textContent = count
    this.totalTarget.textContent = this.money(total)
    this.warningTarget.hidden = !exceeded
    let needsReason = false
    if (this.hasOverrideTarget) {
      this.overrideTarget.disabled = !exceeded
      this.reasonTarget.disabled = !exceeded
      this.reasonTarget.required = exceeded
      needsReason = exceeded && (!this.overrideTarget.checked || !this.reasonTarget.value.trim())
    }
    if (this.hasSubmitTarget) this.submitTarget.disabled = count === 0 || invalid || needsReason
    this.clearTarget.disabled = count === 0 && !invalid
    this.selectionHintTarget.textContent = invalid ? "กรุณากรอกยอดเงินเป็นตัวเลขตั้งแต่ 0 ขึ้นไป" : needsReason ? "ยอดเกินงบ: ยืนยันและระบุเหตุผลในช่องด้านบนก่อนบันทึก" : count === 0 ? "ใส่ยอดเงินอย่างน้อย 1 งานเพื่อบันทึก" : hiddenCount ? `รวม ${hiddenCount} งานที่กรอกไว้นอกผลค้นหาด้วย` : this.adminValue ? "บันทึกครั้งเดียว อนุมัติและหักยอดทันที" : "ส่งคำขอแล้ว รอ Admin อนุมัติก่อนหักยอด"
  }
}
