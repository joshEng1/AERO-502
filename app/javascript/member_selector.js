// KAN-37: turns the assignee checkboxes into a searchable selector.
// The checkboxes stay in the form and are still what gets submitted, so the
// form keeps working without JavaScript.

function setUpMemberSelector(fieldset) {
  const optionsBox = fieldset.querySelector("[data-member-options]")
  const members = Array.from(optionsBox.querySelectorAll("label[data-member-name]")).map((label) => ({
    label,
    checkbox: label.querySelector("input[type=checkbox]"),
    name: label.dataset.memberName,
    teamId: label.dataset.teamId
  }))
  const form = fieldset.closest("form")
  const projectSelect = form && form.querySelector("select[name='task[project_id]']")
  const prefix = `member-selector-${Math.random().toString(36).slice(2, 8)}`

  const chips = document.createElement("ul")
  chips.className = "member-chips"
  chips.setAttribute("aria-label", "Selected members")

  const inputLabel = document.createElement("label")
  inputLabel.htmlFor = `${prefix}-input`
  inputLabel.textContent = "Assignees"

  const input = document.createElement("input")
  input.type = "text"
  input.id = `${prefix}-input`
  input.autocomplete = "off"
  input.placeholder = "Type a name or open the list"
  input.setAttribute("role", "combobox")
  input.setAttribute("aria-autocomplete", "list")
  input.setAttribute("aria-expanded", "false")
  input.setAttribute("aria-controls", `${prefix}-list`)

  const list = document.createElement("ul")
  list.id = `${prefix}-list`
  list.className = "member-options"
  list.setAttribute("role", "listbox")
  list.setAttribute("aria-multiselectable", "true")
  list.setAttribute("aria-label", "Members")
  list.hidden = true

  const status = document.createElement("p")
  status.className = "hint member-status"
  status.setAttribute("role", "status")

  const picker = document.createElement("div")
  picker.className = "member-picker"
  picker.append(chips, inputLabel, input, list, status)
  optionsBox.hidden = true
  optionsBox.after(picker)

  let activeIndex = -1

  function projectTeamId() {
    const option = projectSelect && projectSelect.selectedOptions[0]
    return option ? option.dataset.teamId : undefined
  }

  function eligible(member) {
    const teamId = projectTeamId()
    return !teamId || member.teamId === teamId
  }

  function matches() {
    const query = input.value.trim().toLowerCase()
    return members.filter((member) => eligible(member) && member.name.toLowerCase().includes(query))
  }

  function renderChips() {
    chips.replaceChildren()
    members.filter((member) => member.checkbox.checked).forEach((member) => {
      const chip = document.createElement("li")
      chip.className = "member-chip"
      const name = document.createElement("span")
      name.textContent = member.name
      const remove = document.createElement("button")
      remove.type = "button"
      remove.className = "member-chip-remove"
      remove.setAttribute("aria-label", `Remove ${member.name}`)
      remove.textContent = "×"
      remove.addEventListener("click", () => {
        member.checkbox.checked = false
        renderChips()
        renderList()
        input.focus()
      })
      chip.append(name, remove)
      chips.append(chip)
    })
    chips.hidden = chips.children.length === 0
  }

  function renderList() {
    const shown = matches()
    list.replaceChildren()
    shown.forEach((member, index) => {
      const option = document.createElement("li")
      option.id = `${prefix}-option-${index}`
      option.className = "member-option"
      option.setAttribute("role", "option")
      option.setAttribute("aria-selected", String(member.checkbox.checked))
      option.textContent = member.name
      if (index === activeIndex) option.classList.add("is-active")
      // mousedown keeps focus in the input so the list stays open.
      option.addEventListener("mousedown", (event) => event.preventDefault())
      option.addEventListener("click", () => toggle(member))
      list.append(option)
    })

    if (activeIndex >= shown.length) activeIndex = shown.length - 1
    if (activeIndex >= 0) {
      input.setAttribute("aria-activedescendant", `${prefix}-option-${activeIndex}`)
      list.children[activeIndex].scrollIntoView({ block: "nearest" })
    } else {
      input.removeAttribute("aria-activedescendant")
    }
    status.textContent = list.hidden || shown.length ? "" : "No matching members"
    return shown
  }

  function toggle(member) {
    member.checkbox.checked = !member.checkbox.checked
    renderChips()
    renderList()
  }

  function open() {
    list.hidden = false
    input.setAttribute("aria-expanded", "true")
    renderList()
  }

  function close() {
    list.hidden = true
    activeIndex = -1
    input.setAttribute("aria-expanded", "false")
    renderList()
  }

  input.addEventListener("focus", open)
  input.addEventListener("click", open)
  input.addEventListener("blur", close)
  input.addEventListener("input", () => {
    activeIndex = 0
    open()
  })
  input.addEventListener("keydown", (event) => {
    const shown = matches()
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      if (list.hidden) open()
      if (!shown.length) return
      const step = event.key === "ArrowDown" ? 1 : -1
      activeIndex = (activeIndex + step + shown.length) % shown.length
      renderList()
    } else if (event.key === "Enter") {
      // Enter picks a member instead of submitting the form.
      if (list.hidden) return
      event.preventDefault()
      if (shown[activeIndex]) toggle(shown[activeIndex])
    } else if (event.key === "Escape" && !list.hidden) {
      event.preventDefault()
      close()
    }
  })

  // Members outside the chosen project's team can't be assigned, so drop them.
  if (projectSelect) {
    projectSelect.addEventListener("change", () => {
      const dropped = members.filter((member) => member.checkbox.checked && !eligible(member))
      dropped.forEach((member) => { member.checkbox.checked = false })
      renderChips()
      renderList()
      if (dropped.length) {
        status.textContent = `Removed ${dropped.map((member) => member.name).join(", ")}: not on this project's team.`
      }
    })
  }

  renderChips()
}

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-member-selector]").forEach(setUpMemberSelector)
})
