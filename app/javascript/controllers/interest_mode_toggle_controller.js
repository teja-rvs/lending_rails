import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "mode",
    "rateSection",
    "rateInput",
    "amountSection",
    "amountInput"
  ]

  connect() {
    this.sync()
  }

  sync() {
    const mode = this.modeTarget.value
    const editable = !this.modeTarget.disabled

    if (mode === "rate") {
      this.showRateMode(editable)
    } else if (mode === "total_interest_amount") {
      this.showTotalInterestMode(editable)
    } else {
      this.showPlaceholders()
    }
  }

  showRateMode(editable) {
    this.rateSectionTarget.classList.remove("hidden")
    this.amountSectionTarget.classList.add("hidden")
    this.rateInputTarget.disabled = !editable
    this.amountInputTarget.disabled = true
  }

  showTotalInterestMode(editable) {
    this.rateSectionTarget.classList.add("hidden")
    this.amountSectionTarget.classList.remove("hidden")
    this.rateInputTarget.disabled = true
    this.amountInputTarget.disabled = !editable
  }

  showPlaceholders() {
    this.rateSectionTarget.classList.remove("hidden")
    this.amountSectionTarget.classList.remove("hidden")
    this.rateInputTarget.disabled = true
    this.amountInputTarget.disabled = true
  }
}
