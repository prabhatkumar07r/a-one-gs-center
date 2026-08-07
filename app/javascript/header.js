document.addEventListener("turbo:load", () => {
  const menuBtn = document.querySelector(".mobile-menu-toggle");
  const closeBtn = document.querySelector(".mobile-menu-close");
  const nav = document.querySelector("nav");

  if (menuBtn && nav) {
    menuBtn.addEventListener("click", () => {
      nav.classList.add("active");
    });
  }

  if (closeBtn && nav) {
    closeBtn.addEventListener("click", () => {
      nav.classList.remove("active");
    });
  }

  document.querySelectorAll(".has-dropdown > a").forEach((item) => {
    item.addEventListener("click", (e) => {
      if (window.innerWidth <= 768) {
        e.preventDefault();

        const dropdown = item.nextElementSibling;

        if (dropdown) {
          dropdown.classList.toggle("active");
        }
      }
    });
  });
});