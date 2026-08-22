require "net/http"
require "json"

class BrevoService
  API_URL = "https://api.brevo.com/v3/smtp/email"

  def self.send_email(
    to_email:,
    to_name:,
    subject:,
    html_content:
  )

    api_key = ENV.fetch("BREVO_API_KEY")
    sender_email = ENV.fetch("BREVO_SENDER")
    sender_name = ENV.fetch(
      "BREVO_SENDER_NAME",
      "A-One GS Center"
    )

    Rails.logger.info "BREVO: Starting API request"
    Rails.logger.info "BREVO: Sender #{sender_email}"
    Rails.logger.info "BREVO: Recipient #{to_email}"

    uri = URI.parse(API_URL)

    http = Net::HTTP.new(
      uri.host,
      uri.port
    )

    http.use_ssl = true

    http.open_timeout = 10
    http.read_timeout = 20

    request = Net::HTTP::Post.new(uri.request_uri)

    request["accept"] = "application/json"
    request["content-type"] = "application/json"
    request["api-key"] = api_key

    request.body = {
      sender: {
        name: sender_name,
        email: sender_email
      },

      to: [
        {
          email: to_email,
          name: to_name
        }
      ],

      subject: subject,

      htmlContent: html_content
    }.to_json

    Rails.logger.info "BREVO: Connecting to #{uri.host}:#{uri.port}"

    response = http.request(request)

    Rails.logger.info "BREVO: Response #{response.code}"
    Rails.logger.info "BREVO: #{response.body}"

    response

  rescue Net::OpenTimeout => e

    Rails.logger.error "BREVO OPEN TIMEOUT"
    Rails.logger.error e.full_message

    raise

  rescue Net::ReadTimeout => e

    Rails.logger.error "BREVO READ TIMEOUT"
    Rails.logger.error e.full_message

    raise

  rescue StandardError => e

    Rails.logger.error "BREVO ERROR"
    Rails.logger.error "#{e.class}: #{e.message}"
    Rails.logger.error e.full_message

    raise
  end


  # =========================================================
  # DEVise CONFIRMATION
  # =========================================================

  def self.send_confirmation(user)

    confirmation_url =
      Rails.application.routes.url_helpers.user_confirmation_url(
        confirmation_token: user.confirmation_token,
        host: ENV.fetch(
          "APP_HOST",
          "a-one-gs-center.onrender.com"
        ),
        protocol: "https"
      )

    send_email(
      to_email: user.email,
      to_name: user.name,
      subject: "Confirm your A-One GS Center account",

      html_content: <<~HTML
        <div style="font-family:Arial,sans-serif;max-width:600px;margin:auto">

          <h2>Welcome to A-One GS Center!</h2>

          <p>
            Hello #{ERB::Util.html_escape(user.name)},
          </p>

          <p>
            Your account has been created successfully.
          </p>

          <p>
            Please confirm your email address.
          </p>

          <p style="margin:30px 0">

            <a
              href="#{confirmation_url}"
              style="
                display:inline-block;
                padding:12px 24px;
                background:#2563eb;
                color:#ffffff;
                text-decoration:none;
                border-radius:6px;
              "
            >
              Confirm My Email
            </a>

          </p>

          <p>
            Regards,<br>
            <strong>A-One GS Center</strong>
          </p>

        </div>
      HTML
    )
  end


  # =========================================================
  # CONTACT FORM
  # =========================================================

  def self.send_contact(contact)

    send_email(
      to_email: ENV.fetch("BREVO_SENDER"),
      to_name: "Admin",
      subject: "New Contact Form Enquiry",

      html_content: <<~HTML
        <h2>New Contact Form Submission</h2>

        <p>
          <strong>Name:</strong>
          #{ERB::Util.html_escape(contact.name)}
        </p>

        <p>
          <strong>Email:</strong>
          #{ERB::Util.html_escape(contact.email)}
        </p>

        <p>
          <strong>Mobile:</strong>
          #{ERB::Util.html_escape(contact.mobile)}
        </p>

        <p>
          <strong>Subject:</strong>
          #{ERB::Util.html_escape(contact.subject)}
        </p>

        <p>
          <strong>Message:</strong>
        </p>

        <p>
          #{ERB::Util.html_escape(contact.message)}
        </p>
      HTML
    )
  end
end