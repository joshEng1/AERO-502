// Native multiple-select remains usable when JavaScript is unavailable.
export function initializeMemberSelectors(root = document) {
  root.querySelectorAll("[data-member-selector]").forEach(container => {
    if (container.dataset.ready) return;
    container.dataset.ready = "true";
    const source = container.querySelector("[data-member-source]");
    const form = source.form;
    const project = form.querySelector("#task_project_id");
    const primary = form.querySelector("#task_primary_contact_id");
    const prerequisites = form.querySelector("#task_prerequisite_ids");
    const input = document.createElement("input");
    input.id = "task_member_search";
    input.type = "search";
    input.placeholder = "Search members";
    input.autocomplete = "off";
    input.setAttribute("role", "combobox");
    input.setAttribute("aria-autocomplete", "list");
    input.setAttribute("aria-controls", "member-options");
    input.setAttribute("aria-expanded", "false");
    input.setAttribute("aria-describedby", "member-selector-help");
    container.querySelector("label").htmlFor = input.id;
    const chips = document.createElement("div");
    chips.className = "member-chips";
    chips.setAttribute("aria-label", "Selected members");
    const list = document.createElement("div");
    list.id = "member-options";
    list.className = "member-options";
    list.setAttribute("role", "listbox");
    list.setAttribute("aria-label", "Eligible members");
    list.setAttribute("aria-multiselectable", "true");
    list.hidden = true;
    const message = document.createElement("p");
    message.className = "hint";
    message.setAttribute("role", "status");
    source.hidden = true;
    container.append(chips, input, list, message);
    let activeIndex = -1;
    let visible = [];
    const options = Array.from(source.options);
    const teamId = () => project.selectedOptions[0]?.dataset.teamId;
    const close = () => {
      list.hidden = true;
      input.setAttribute("aria-expanded", "false");
      input.removeAttribute("aria-activedescendant");
      activeIndex = -1;
    };
    const render = () => {
      const query = input.value.trim().toLocaleLowerCase();
      visible = options.filter(option => option.dataset.teamId === teamId() && option.textContent.toLocaleLowerCase().includes(query));
      list.replaceChildren();
      activeIndex = -1;
      input.removeAttribute("aria-activedescendant");
      visible.forEach((option, index) => {
        const row = document.createElement("div");
        row.id = "member-option-" + option.value;
        row.setAttribute("role", "option");
        row.setAttribute("aria-selected", String(option.selected));
        row.textContent = option.textContent;
        row.addEventListener("mousedown", event => event.preventDefault());
        row.addEventListener("click", () => toggle(option));
        list.append(row);
      });
      message.textContent = !teamId() ? "Select a project to browse eligible members." :
        visible.length === 0 ? "No matching members" : visible.length + " matching members";
    };
    const renderSelections = () => {
      chips.replaceChildren();
      options.filter(option => option.selected).forEach(option => {
        const chip = document.createElement("button");
        chip.type = "button";
        chip.className = "member-chip";
        chip.textContent = option.textContent + " ×";
        chip.setAttribute("aria-label", "Remove " + option.textContent);
        chip.addEventListener("click", () => { toggle(option); input.focus(); });
        chips.append(chip);
      });
      const previous = primary.value;
      primary.replaceChildren(new Option("No primary contact", ""));
      options.filter(option => option.selected).forEach(option => primary.add(new Option(option.textContent, option.value)));
      primary.value = options.some(option => option.selected && option.value === previous) ? previous : "";
    };
    const toggle = option => {
      option.selected = !option.selected;
      renderSelections();
      render();
    };
    const open = () => {
      render();
      list.hidden = false;
      input.setAttribute("aria-expanded", "true");
      // Opening near the bottom of the page must reveal the bounded list.
      list.scrollIntoView({block: "nearest"});
    };
    // Scrolling during pointer-down moves the input before the click finishes.
    // Pointer users open on click; keyboard users still open as soon as they focus.
    let pointerDown = false;
    input.addEventListener("pointerdown", () => { pointerDown = true; });
    input.addEventListener("pointerup", () => { pointerDown = false; });
    input.addEventListener("pointercancel", () => { pointerDown = false; });
    input.addEventListener("blur", () => { pointerDown = false; });
    input.addEventListener("focus", () => { if (!pointerDown) open(); });
    input.addEventListener("click", open);
    input.addEventListener("input", open);
    input.addEventListener("keydown", event => {
      if (event.key === "Escape") { event.preventDefault(); close(); return; }
      if (event.key === "Tab") { close(); return; }
      if (event.key === "ArrowDown" || event.key === "ArrowUp") {
        event.preventDefault();
        if (list.hidden) open();
        if (visible.length === 0) return;
        const step = event.key === "ArrowDown" ? 1 : -1;
        activeIndex = (activeIndex + step + visible.length) % visible.length;
        Array.from(list.children).forEach((row, index) => row.classList.toggle("is-active", index === activeIndex));
        const row = list.children[activeIndex];
        input.setAttribute("aria-activedescendant", row.id);
        row.scrollIntoView({block: "nearest"});
      } else if (event.key === "Enter" && !list.hidden) {
        event.preventDefault();
        if (activeIndex >= 0) toggle(visible[activeIndex]);
      }
    });
    container.addEventListener("focusout", event => {
      if (!container.contains(event.relatedTarget)) close();
    });
    const updateProject = () => {
      for (const option of prerequisites.options) {
        option.hidden = option.dataset.teamId !== teamId();
        // Preserve submitted choices; invalid foreign choices are rejected server-side.
      }
      render();
    };
    project.addEventListener("change", updateProject);
    renderSelections();
    updateProject();
  });
}

function initializeRoleFields(root = document) {
  root.querySelectorAll("[data-role-fields]").forEach(container => {
    if (container.dataset.ready) return;
    container.dataset.ready = "true";
    const role = container.querySelector("#user_role");
    const subteam = container.querySelector("#user_subteam_id");
    role.addEventListener("change", () => {
      if (role.value === "chief_engineer") subteam.value = "";
      subteam.required = role.value !== "chief_engineer";
    });
    subteam.required = role.value !== "chief_engineer";
  });
}

export function initializeForms() {
  initializeMemberSelectors();
  initializeRoleFields();
}
document.addEventListener("DOMContentLoaded", initializeForms);
document.addEventListener("turbo:load", initializeForms);
