document.addEventListener("DOMContentLoaded", () => {
  const button = document.getElementById("studentProfileButton");
  const menu = document.getElementById("studentProfileMenu");

  if (!button || !menu) return;

  button.addEventListener("click", (event) => {
    event.stopPropagation();

    const isOpen = menu.classList.toggle("open");

    button.classList.toggle("active", isOpen);
    button.setAttribute("aria-expanded", isOpen);
  });

  document.addEventListener("click", (event) => {
    if (!event.target.closest(".student-profile-dropdown")) {
      menu.classList.remove("open");
      button.classList.remove("active");
      button.setAttribute("aria-expanded", "false");
    }
  });
});