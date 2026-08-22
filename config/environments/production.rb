require "active_support/core_ext/integer/time"

Rails.application.configure do

  config.public_file_server.enabled =
    ENV["RAILS_SERVE_STATIC_FILES"].present?

  config.enable_reloading = false
  config.eager_load = true

  config.consider_all_requests_local = false

  config.action_controller.perform_caching = true

  config.public_file_server.headers = {
    "cache-control" => "public, max-age=#{1.year.to_i}"
  }

  # =========================================================
  # ACTIVE STORAGE
  # =========================================================

  config.active_storage.service = :cloudinary

  # =========================================================
  # SSL
  # =========================================================

  config.assume_ssl = true
  config.force_ssl = true

  # =========================================================
  # LOGGING
  # =========================================================

  config.log_tags = [:request_id]

  config.logger =
    ActiveSupport::TaggedLogging.logger(STDOUT)

  config.log_level =
    ENV.fetch("RAILS_LOG_LEVEL", "info")

  config.silence_healthcheck_path = "/up"

  config.active_support.report_deprecations = false

  # =========================================================
  # CACHE
  # =========================================================

  config.cache_store = :solid_cache_store

  # =========================================================
  # ACTIVE JOB
  # =========================================================

  config.active_job.queue_adapter = :async

  # =========================================================
  # ACTION MAILER - BREVO SMTP
  # =========================================================




  config.action_mailer.default_url_options = {
    host: ENV.fetch(
      "APP_HOST",
      "a-one-gs-center.onrender.com"
    ),
    protocol: "https"
  }

  config.action_mailer.default_options = {
    from: ENV.fetch("BREVO_SENDER")
  }

  config.action_mailer.raise_delivery_errors = true

  # =========================================================
  # I18N
  # =========================================================

  config.i18n.fallbacks = true

  # =========================================================
  # ACTIVE RECORD
  # =========================================================

  config.active_record.dump_schema_after_migration = false

  config.active_record.attributes_for_inspect = [:id]

end