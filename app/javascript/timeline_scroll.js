// KAN-23: the timeline scrolls sideways instead of paging through weeks.
// On load it brings today into view, and "Jump to today" returns there.

function scrollToToday(scroller, behavior) {
  const today = scroller.querySelector("[data-today]")
  const label = scroller.querySelector(".gantt-corner")
  if (!today) return

  // Keep about a week of past dates visible to the left of today.
  const labelWidth = label ? label.offsetWidth : 0
  const visible = scroller.clientWidth - labelWidth
  scroller.scrollTo({ left: today.offsetLeft - labelWidth - visible / 4, behavior })
}

document.addEventListener("DOMContentLoaded", () => {
  const scroller = document.querySelector("[data-gantt-scroll]")
  if (!scroller) return

  scrollToToday(scroller, "auto")

  const button = document.querySelector("[data-scroll-today]")
  if (button) {
    button.hidden = false
    button.addEventListener("click", () => scrollToToday(scroller, "smooth"))
  }
})
