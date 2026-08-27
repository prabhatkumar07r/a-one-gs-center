Rails.application.config.session_store :cookie_store,
  key: "_my_first_learn_session",
  same_site: :lax,
  secure: Rails.env.production?