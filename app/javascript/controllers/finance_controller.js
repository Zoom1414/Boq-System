import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["picker", "name", "unit", "quantity", "material", "labor", "rows", "row", "template", "total", "empty", "error", "hint", "boqFields", "outsideFields", "boqTab", "outsideTab", "warning"]
  static values = { mode: String }

  connect() { this.outside = false; this.sequence = Date.now(); this.calculate() }
  rowTargetConnected() { if (this.hasTotalTarget) this.calculate() }
  useBoq() { this.setOutside(false) }
  useOutside() { this.setOutside(true) }
  setOutside(value) {
    this.outside = value
    this.boqFieldsTarget.hidden = value
    this.outsideFieldsTarget.hidden = !value
    this.boqTabTarget.classList.toggle("is-active", !value)
    this.outsideTabTarget.classList.toggle("is-active", value)
    this.hintTarget.textContent = value ? "รายการนอก BOQ แสดงแยกในเอกสาร และไม่หักงบ Master BOQ" : "เลือก BOQ เพื่อดึงราคาและตรวจยอดคงเหลือ"
    this.errorTarget.hidden = true
    if (!value) this.selectItem()
  }
  selectItem() {
    const option = this.pickerTarget.selectedOptions[0]
    if (!option?.value) return
    this.materialTarget.value = option.dataset.material
    this.laborTarget.value = option.dataset.labor
    this.hintTarget.textContent = `วัสดุคงเหลือ ${option.dataset.remaining} ${option.dataset.unit} · ค่าแรงคงเหลือ ${this.money(option.dataset.laborRemaining)} บาท`
  }
  add() {
    const option = this.pickerTarget.selectedOptions[0]
    const id = this.outside ? "" : option?.value
    const name = this.outside ? this.nameTarget.value.trim() : option?.dataset.name
    const unit = this.outside ? this.unitTarget.value.trim() : option?.dataset.unit
    const quantity = Number(this.quantityTarget.value), material = Number(this.materialTarget.value), labor = Number(this.laborTarget.value)
    let error = ""
    if (!name || (!this.outside && !id)) error = "กรุณาเลือกรายการ หรือระบุชื่องานนอก BOQ"
    else if (!unit) error = "กรุณาระบุหน่วย"
    else if (!this.quantityTarget.value || !this.materialTarget.value || !this.laborTarget.value || ![quantity, material, labor].every(Number.isFinite) || quantity <= 0 || material < 0 || labor < 0) error = "กรุณากรอกจำนวนมากกว่า 0 และราคาไม่ติดลบ"
    else if (id && this.rowTargets.some(row => row.querySelector('[data-field="boq-id"]').value === id)) error = "มีรายการ BOQ นี้แล้ว กรุณาแก้จำนวนที่แถวเดิม"
    if (error) { this.errorTarget.textContent = error; this.errorTarget.hidden = false; return }
    const fragment = this.templateTarget.content.cloneNode(true)
    const index = String(++this.sequence)
    fragment.querySelectorAll("input").forEach(input => { input.name = input.name.replace("NEW_ROW", index); input.removeAttribute("id") })
    const row = fragment.querySelector("tr")
    const set = (field, value) => { row.querySelector(`[data-field="${field}"]`).value = value }
    set("boq-id", id); set("name", name); set("unit", unit); set("quantity", quantity); set("material", material); set("labor", labor)
    row.querySelector('[data-field="label"]').textContent = name
    row.querySelector('[data-field="unit-label"]').textContent = `${unit}${this.outside ? " · นอก BOQ" : ""}`
    this.rowsTarget.append(fragment)
    this.errorTarget.hidden = true
    this.calculate()
  }
  remove(event) { event.currentTarget.closest("tr").remove(); this.calculate() }
  money(value) { return Number(value || 0).toLocaleString("en-US", {minimumFractionDigits: 2, maximumFractionDigits: 2}) }
  calculate() {
    let total = 0, exceeded = false
    this.rowTargets.forEach(row => {
      const input = field => Number(row.querySelector(`[data-field="${field}"]`)?.value || 0)
      const show = (field, value) => { const cell = row.querySelector(`[data-field="${field}"]`); if (cell) cell.textContent = this.money(value) }
      if (this.modeValue === "dv") {
        const amount = input("requested"), remaining = Number(row.dataset.remaining) - amount
        total += amount; exceeded ||= remaining < 0
        show("remaining", remaining)
        row.querySelector('[data-field="remaining"]').classList.toggle("red-text", remaining < 0)
      } else {
        const quantity = this.modeValue === "pu" ? Number(row.dataset.quantity) : input("quantity")
        const laborPrice = this.modeValue === "pu" ? Number(row.dataset.labor) : input("labor")
        const material = Math.round(quantity * input("material") * 100) / 100
        const labor = Math.round(quantity * laborPrice * 100) / 100
        show("material-total", material); show("labor-total", labor); show("total", material + labor)
        total += material + labor
      }
    })
    if (this.hasTotalTarget) this.totalTarget.textContent = this.money(total)
    if (this.hasEmptyTarget) this.emptyTarget.hidden = this.rowTargets.length > 0
    if (this.hasWarningTarget) this.warningTarget.hidden = !exceeded
  }
}
