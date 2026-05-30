import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Theme is already applied by the inline script in <head> before the page renders.
  // This controller only handles the toggle action.
  toggle() {
    const current = document.documentElement.getAttribute("data-theme") || "light"
    const next = current === "dark" ? "light" : "dark"
    document.documentElement.setAttribute("data-theme", next)
    localStorage.setItem("theme", next)
  }
}
