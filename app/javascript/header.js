document.addEventListener("turbo:load", () => {

  /* =========================================================
     MOBILE MENU
  ========================================================== */

  const menuBtn = document.getElementById("mobileMenuToggle");
  const closeBtn = document.getElementById("mobileMenuClose");
  const nav = document.getElementById("mainNavigation");


  if (menuBtn && nav) {

    menuBtn.addEventListener("click", (event) => {

      event.stopPropagation();

      nav.classList.add("active");

    });

  }


  if (closeBtn && nav) {

    closeBtn.addEventListener("click", (event) => {

      event.stopPropagation();

      nav.classList.remove("active");

    });

  }


  /* =========================================================
     STUDENT PROFILE DROPDOWN
  ========================================================== */

  const profileButton =
    document.getElementById("studentProfileButton");

  const profileMenu =
    document.getElementById("studentProfileMenu");


  if (profileButton && profileMenu) {

    /* -----------------------------------------
       OPEN / CLOSE
    ----------------------------------------- */

    profileButton.addEventListener("click", (event) => {

      event.preventDefault();

      event.stopPropagation();

      const isOpen =
        profileMenu.classList.contains("open");


      /* Toggle */

      profileMenu.classList.toggle("open");

      profileButton.classList.toggle("active");

      profileButton.setAttribute(
        "aria-expanded",
        String(!isOpen)
      );

      profileMenu.setAttribute(
        "aria-hidden",
        String(isOpen)
      );

    });


    /* -----------------------------------------
       PREVENT MENU CLICK FROM CLOSING
    ----------------------------------------- */

    profileMenu.addEventListener("click", (event) => {

      event.stopPropagation();

    });


    /* -----------------------------------------
       CLICK OUTSIDE
    ----------------------------------------- */

    document.addEventListener("click", (event) => {

      if (
        !profileButton.contains(event.target) &&
        !profileMenu.contains(event.target)
      ) {

        profileMenu.classList.remove("open");

        profileButton.classList.remove("active");

        profileButton.setAttribute(
          "aria-expanded",
          "false"
        );

        profileMenu.setAttribute(
          "aria-hidden",
          "true"
        );

      }

    });


    /* -----------------------------------------
       ESC KEY
    ----------------------------------------- */

    document.addEventListener("keydown", (event) => {

      if (event.key === "Escape") {

        profileMenu.classList.remove("open");

        profileButton.classList.remove("active");

        profileButton.setAttribute(
          "aria-expanded",
          "false"
        );

        profileMenu.setAttribute(
          "aria-hidden",
          "true"
        );

      }

    });

  }


});