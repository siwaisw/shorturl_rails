import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }
  static targets = ["total", "linkCount"]

  connect() {
    this.timer = setInterval(() => this.poll(), 5000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async poll() {
    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })
      if (!response.ok) return
      if (!response.headers.get("Content-Type")?.includes("application/json")) return
      const data = await response.json()

      if (this.hasTotalTarget) {
        this.totalTarget.textContent = data.total_clicks
      }

      this.linkCountTargets.forEach(el => {
        const link = data.links.find(l => l.id == el.dataset.id)
        if (link) el.textContent = link.click_count
      })
    } catch (_) {
      // silently ignore network errors
    }
  }
}
