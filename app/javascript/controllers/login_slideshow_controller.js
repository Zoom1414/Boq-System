import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide"]

  connect() {
    if (this.slideTargets.length < 2 || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.currentIndex = 0
    this.timer = window.setInterval(() => this.showNext(), 5000)
  }

  disconnect() {
    window.clearInterval(this.timer)
  }

  showNext() {
    this.slideTargets[this.currentIndex].classList.remove("is-active")
    this.currentIndex = (this.currentIndex + 1) % this.slideTargets.length
    this.slideTargets[this.currentIndex].classList.add("is-active")
  }
}