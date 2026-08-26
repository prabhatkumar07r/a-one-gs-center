
/* =========================================================
   HEADER
========================================================= */

.header {
  position: fixed;
  top: 0;
  left: 0;

  width: 100%;
  height: 80px;

  background: #ffffff;

  box-shadow: 0 2px 15px rgba(0, 0, 0, 0.08);

  z-index: 9999;

  .container {
    height: 100%;
  }
}


/* =========================================================
   HEADER CONTENT
========================================================= */

.header-content {
  height: 100%;

  display: flex;
  align-items: center;

  gap: 25px;
}


/* =========================================================
   LOGO
========================================================= */

.logo {
  display: flex;
  align-items: center;

  flex-shrink: 0;

  text-decoration: none;

  img {
    height: 60px;
    width: auto;

    display: block;

    object-fit: contain;
  }
}


/* =========================================================
   MAIN NAVIGATION
========================================================= */

.main-navigation {
  margin-left: auto;

  ul {
    display: flex;
    align-items: center;

    gap: 25px;

    margin: 0;
    padding: 0;

    list-style: none;
  }

  li {
    list-style: none;
  }

  a {
    display: inline-flex;
    align-items: center;

    padding: 8px 15px;

    border-radius: 30px;

    color: #333333;

    text-decoration: none;

    font-size: 16px;
    font-weight: 600;

    transition: all 0.3s ease;

    &:hover {
      background: #f4f4f4;
      color: #6a11cb;
    }
  }
}


/* =========================================================
   HEADER RIGHT
========================================================= */

.header-right {
  display: flex;
  align-items: center;

  gap: 15px;

  flex-shrink: 0;

  margin-left: 20px;
}


/* =========================================================
   STUDENT PROFILE CONTAINER
========================================================= */

.student-profile-dropdown {
  position: relative;

  display: inline-block;
}


/* =========================================================
   PROFILE BUTTON
========================================================= */

.student-profile-button {
  appearance: none;
  -webkit-appearance: none;

  display: flex;
  align-items: center;

  gap: 10px;

  height: 52px;
  min-width: 190px;

  padding: 6px 12px 6px 7px;

  margin: 0;

  background: #ffffff;

  border: 1px solid #e5e7eb;

  border-radius: 30px;

  color: #1f2937;

  font-family: "Poppins", sans-serif;

  cursor: pointer;

  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.06);

  transition: all 0.2s ease;

  &:hover {
    background: #f8fafc;

    border-color: #d1d5db;

    box-shadow: 0 5px 15px rgba(0, 0, 0, 0.10);
  }

  &:focus {
    outline: none;

    border-color: #7c3aed;

    box-shadow:
      0 0 0 3px rgba(124, 58, 237, 0.12);
  }

  &.active {
    border-color: #7c3aed;
  }
}


/* =========================================================
   HEADER AVATAR
========================================================= */

.student-header-avatar {
  width: 40px;
  height: 40px;

  min-width: 40px;

  display: flex;
  align-items: center;
  justify-content: center;

  overflow: hidden;

  border-radius: 50%;

  background: #eef2f7;

  border: 2px solid #e5e7eb;

  color: #64748b;

  font-size: 18px;
}

.student-header-avatar-image {
  width: 100%;
  height: 100%;

  display: block;

  object-fit: cover;
}


/* =========================================================
   USER NAME
========================================================= */

.student-header-name {
  max-width: 110px;

  overflow: hidden;

  text-overflow: ellipsis;

  white-space: nowrap;

  font-size: 14px;

  font-weight: 600;

  color: #1f2937;
}


/* =========================================================
   DROPDOWN ARROW
========================================================= */

.student-dropdown-arrow {
  margin-left: auto;

  font-size: 12px;

  color: #6b7280;

  transition: transform 0.2s ease;
}

.student-profile-button.active
.student-dropdown-arrow {
  transform: rotate(180deg);
}


/* =========================================================
   DROPDOWN MENU
========================================================= */

.student-dropdown-menu {
  position: absolute;

  top: calc(100% + 10px);

  right: 0;

  width: 310px;

  display: none;

  padding: 8px;

  background: #ffffff;

  border: 1px solid #e5e7eb;

  border-radius: 16px;

  box-shadow: 0 15px 40px rgba(0, 0, 0, 0.15);

  z-index: 100000;

  opacity: 0;

  transform: translateY(-5px);

  transition:
    opacity 0.18s ease,
    transform 0.18s ease;

  pointer-events: none;
}


/* OPEN STATE */

.student-dropdown-menu.open {
  display: block;

  opacity: 1;

  transform: translateY(0);

  pointer-events: auto;
}


/* =========================================================
   USER INFORMATION
========================================================= */

.student-dropdown-user {
  display: flex;
  align-items: center;

  gap: 12px;

  padding: 13px 12px;
}


/* =========================================================
   DROPDOWN AVATAR
========================================================= */

.student-dropdown-avatar {
  width: 50px;
  height: 50px;

  min-width: 50px;

  display: flex;
  align-items: center;
  justify-content: center;

  overflow: hidden;

  border-radius: 50%;

  background: #eef2f7;

  border: 2px solid #e5e7eb;

  color: #64748b;

  font-size: 20px;
}

.student-dropdown-avatar img {
  width: 100%;
  height: 100%;

  display: block;

  object-fit: cover;
}


/* =========================================================
   USER INFORMATION TEXT
========================================================= */

.student-dropdown-info {
  min-width: 0;

  display: flex;
  flex-direction: column;
}

.student-dropdown-info strong {
  display: block;

  color: #111827;

  font-size: 15px;

  font-weight: 700;
}

.student-dropdown-info small {
  display: block;

  max-width: 190px;

  margin-top: 3px;

  overflow: hidden;

  text-overflow: ellipsis;

  white-space: nowrap;

  color: #6b7280;

  font-size: 12px;
}


/* =========================================================
   ROLE
========================================================= */

.student-role {
  width: fit-content;

  margin-top: 6px;

  padding: 3px 9px;

  background: #7c3aed;

  color: #ffffff;

  border-radius: 20px;

  font-size: 10px;

  font-weight: 700;

  line-height: 1.4;
}


/* =========================================================
   DIVIDER
========================================================= */

.student-dropdown-divider {
  height: 1px;

  margin: 7px 4px;

  background: #e5e7eb;
}


/* =========================================================
   DROPDOWN ITEMS
========================================================= */

.student-dropdown-item {
  appearance: none;
  -webkit-appearance: none;

  display: flex;
  align-items: center;

  gap: 12px;

  width: 100%;

  min-height: 44px;

  padding: 11px 13px;

  margin: 0;

  border: 0;

  border-radius: 9px;

  background: transparent;

  color: #374151;

  text-decoration: none;

  font-family: "Poppins", sans-serif;

  font-size: 14px;

  font-weight: 500;

  cursor: pointer;

  text-align: left;

  transition: all 0.2s ease;

  &:hover {
    background: #f3f4f6;

    color: #111827;
  }

  i {
    width: 20px;

    flex-shrink: 0;

    color: #64748b;

    font-size: 18px;

    text-align: center;

    transition: color 0.2s ease;
  }

  &:hover i {
    color: #7c3aed;
  }
}


/* =========================================================
   LOGOUT
========================================================= */

.student-logout {
  color: #dc2626 !important;

  i {
    color: #dc2626 !important;
  }

  &:hover {
    background: #fef2f2;

    color: #dc2626 !important;
  }
}

.student-logout-form {
  display: block;

  width: 100%;

  margin: 0;
}


/* =========================================================
   LOGIN BUTTON
========================================================= */

.auth-btn {
  display: inline-flex;
  align-items: center;

  gap: 8px;

  padding: 10px 24px;

  border: none;

  border-radius: 40px;

  background: linear-gradient(
    to right,
    #6a11cb,
    #2575fc
  );

  color: #ffffff;

  text-decoration: none;

  font-size: 14px;

  font-weight: 600;

  cursor: pointer;

  transition: all 0.3s ease;

  box-shadow:
    0 2px 8px rgba(106, 17, 203, 0.2);

  &:hover {
    background: linear-gradient(
      to right,
      #7b1fe0,
      #3a7cf5
    );

    color: #ffffff;

    transform: translateY(-2px);

    box-shadow:
      0 6px 16px rgba(106, 17, 203, 0.3);
  }
}


/* =========================================================
   MOBILE MENU
========================================================= */

.mobile-menu-toggle,
.mobile-menu-close {
  display: none;
}


/* =========================================================
   TABLET
========================================================= */

@media (max-width: 992px) {

  .main-navigation {
    ul {
      gap: 10px;
    }

    a {
      padding: 7px 10px;

      font-size: 14px;
    }
  }

  .student-profile-button {
    min-width: 165px;
  }

  .student-header-name {
    max-width: 90px;
  }

  .header-right {
    gap: 10px;
  }
}


/* =========================================================
   MOBILE
========================================================= */

@media (max-width: 768px) {

  .header-content {
    gap: 10px;
  }

  .main-navigation {
    position: fixed;

    top: 80px;
    left: -100%;

    width: 280px;

    height: calc(100vh - 80px);

    padding: 25px;

    background: #ffffff;

    box-shadow:
      0 5px 15px rgba(0, 0, 0, 0.15);

    transition: left 0.3s ease;

    &.active {
      left: 0;
    }

    ul {
      flex-direction: column;

      align-items: flex-start;

      gap: 8px;
    }
  }


  .mobile-menu-toggle {
    display: block;

    border: none;

    background: transparent;

    font-size: 28px;

    cursor: pointer;
  }


  .mobile-menu-close {
    display: block;

    border: none;

    background: transparent;

    font-size: 24px;

    margin-bottom: 20px;

    cursor: pointer;
  }


  .student-header-name {
    display: none;
  }


  .student-profile-button {
    min-width: auto;

    padding-right: 10px;
  }


  .student-dropdown-menu {
    right: 0;

    width: 290px;
  }


  .header-right {
    margin-left: auto;
  }
}


/* =========================================================
   SMALL MOBILE
========================================================= */

@media (max-width: 480px) {

  .student-dropdown-menu {
    right: -10px;

    width: 280px;
  }

  .student-dropdown-info small {
    max-width: 165px;
  }
}
