pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

pin "bootstrap", to: "bootstrap.bundle.min.js"

pin "chartkick", to: "chartkick.js"

pin "notification", to: "notification.js"
pin "custom", to: "custom.js"
pin "header", to: "header.js"
pin "profile", to: "profile.js"