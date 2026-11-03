// Enhance the existing, permission-scoped select; it still submits the member ID.
// Without JavaScript, the native select remains available.
export function initializeMemberFilters(root = document) {
  root.querySelectorAll("[data-member-filter]").forEach(container => {
    if (container.dataset.memberFilterReady) return;
    const source = container.querySelector("[data-member-filter-source]");
    const options = Array.from(source.options);
    const control = document.createElement("div");
    control.className = "member-filter-control";
    const input = document.createElement("input");
    input.id = source.id + "_search";
    input.type = "text";
    input.autocomplete = "off";
    input.spellcheck = false;
    input.setAttribute("role", "combobox");
    input.setAttribute("aria-autocomplete", "list");
    input.setAttribute("aria-expanded", "false");
    const help = document.createElement("span");
    help.id = source.id + "_help";
    help.className = "visually-hidden";
    help.textContent = "Type part of a name, then choose a member. Use arrow keys and Enter, or select All members to clear this filter.";
    input.setAttribute("aria-describedby", help.id);
    const clear = document.createElement("button");
    clear.type = "button";
    clear.className = "member-filter-clear";
    clear.textContent = "×";
    clear.setAttribute("aria-label", "Clear member filter");
    const popup = document.createElement("div");
    popup.className = "member-filter-popup";
    popup.hidden = true;
    const list = document.createElement("div");
    list.id = source.id + "_options";
    list.className = "member-filter-options";
    list.setAttribute("role", "listbox");
    list.setAttribute("aria-label", "Members");
    input.setAttribute("aria-controls", list.id);
    const message = document.createElement("p");
    message.className = "member-filter-message";
    message.setAttribute("role", "status");
    popup.append(list, message);
    control.append(input, clear, popup, help);
    container.append(control);
    container.querySelector("label").htmlFor = input.id;
    source.hidden = true;
    container.dataset.memberFilterReady = "true";
    let visible = [];
    let activeIndex = -1;

    const syncSelection = () => {
      input.value = source.value ? source.selectedOptions[0].textContent : "";
      input.placeholder = "All members — search by name";
      clear.hidden = !source.value;
    };
    const close = () => {
      popup.hidden = true;
      input.setAttribute("aria-expanded", "false");
      input.removeAttribute("aria-activedescendant");
      activeIndex = -1;
      // Unselected search text must never masquerade as an applied filter.
      syncSelection();
    };
    const choose = option => {
      source.value = option.value;
      source.dispatchEvent(new Event("change", { bubbles: true }));
      input.focus({ preventScroll: true });
      close();
    };
    const open = (query = "") => {
      const needle = query.trim().toLocaleLowerCase();
      visible = options.filter(option => !option.disabled && option.textContent.toLocaleLowerCase().includes(needle));
      list.replaceChildren();
      activeIndex = -1;
      input.removeAttribute("aria-activedescendant");
      visible.forEach((option, index) => {
        const row = document.createElement("div");
        row.id = list.id + "_" + index;
        row.setAttribute("role", "option");
        row.setAttribute("aria-selected", String(option.selected));
        row.textContent = option.textContent;
        // Keep focus on the input until the option's click completes.
        row.addEventListener("mousedown", event => event.preventDefault());
        row.addEventListener("click", () => choose(option));
        list.append(row);
      });
      message.textContent = visible.length ? "Type to narrow the list" : "No matching members";
      popup.hidden = false;
      input.setAttribute("aria-expanded", "true");
    };
    let selectOnClick = false;
    input.addEventListener("pointerdown", () => {
      selectOnClick = document.activeElement !== input || popup.hidden;
    });
    input.addEventListener("focus", () => { open(); input.select(); });
    input.addEventListener("click", () => {
      if (popup.hidden) { open(); input.select(); }
      // Select after the pointer sequence so the first click replaces the saved name.
      else if (selectOnClick) input.select();
      selectOnClick = false;
    });
    input.addEventListener("input", () => {
      if (!input.value) {
        source.value = "";
        clear.hidden = true;
        source.dispatchEvent(new Event("change", { bubbles: true }));
      }
      open(input.value);
    });
    input.addEventListener("keydown", event => {
      if (event.isComposing) return;
      if (event.key === "Escape") { event.preventDefault(); close(); return; }
      if (event.key === "Tab") { close(); return; }
      if (event.key === "ArrowDown" || event.key === "ArrowUp") {
        event.preventDefault();
        if (popup.hidden) open();
        if (!visible.length) return;
        const step = event.key === "ArrowDown" ? 1 : -1;
        activeIndex = activeIndex < 0 ? (step > 0 ? 0 : visible.length - 1) :
          Math.max(0, Math.min(visible.length - 1, activeIndex + step));
        Array.from(list.children).forEach((row, index) => {
          row.classList.toggle("is-active", index === activeIndex);
          row.setAttribute("aria-selected", String(index === activeIndex));
        });
        const row = list.children[activeIndex];
        input.setAttribute("aria-activedescendant", row.id);
        row.scrollIntoView({ block: "nearest" });
      } else if (event.key === "Enter" && !popup.hidden) {
        event.preventDefault();
        const option = activeIndex >= 0 ? visible[activeIndex] : (visible.length === 1 ? visible[0] : null);
        if (option) choose(option);
      }
    });
    clear.addEventListener("click", () => choose(options.find(option => option.value === "")));
    container.addEventListener("focusout", event => {
      if (!container.contains(event.relatedTarget)) close();
    });
    // Clicking non-focusable content outside also closes the popup on touch devices.
    document.addEventListener("click", event => {
      if (!container.contains(event.target)) close();
    });
    source.form.addEventListener("submit", close);
    source.form.addEventListener("reset", () => requestAnimationFrame(close));
    syncSelection();
  });
}

document.addEventListener("DOMContentLoaded", () => initializeMemberFilters());
document.addEventListener("turbo:load", () => initializeMemberFilters());
