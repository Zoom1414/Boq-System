import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() { if (this.element.open) this.element.close(); this.element.showModal() }
  close() { this.element.close(); this.element.closest("turbo-frame").replaceChildren() }
  disconnect() { if (this.element.open) this.element.close() }
}
