require "net/http"
require "json"
require "uri"

class BrevoService
  API_URL = "https://api.brevo.com/v3/smtp/email"

  def self.send_email(to:, subject:, html_content:, text_content: nil)
    uri = URI(API_URL)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)

    request["accept"] = "application/json"
    request["content-type"] = "application/json"
    request["api-key"] = ENV.fetch("BREVO_API_KEY")

    body = {
      sender: {
        name: "A-One GS Center",
        email: ENV.fetch("BREVO_SENDER")
      },
      to: to,
      subject: subject,
      htmlContent: html_content
    }

    body[:textContent] = text_content if text_content.present?

    request.body = body.to_json

    response = http.request(request)

    Rails.logger.info(
      "Brevo API Status: #{response.code}"
    )

    Rails.logger.info(
      "Brevo API Response: #{response.body}"
    )

    unless response.is_a?(Net::HTTPSuccess)
      raise "Brevo API failed: #{response.code} #{response.body}"
    end

    response
  end

  # ================= CONTACT FORM =================

  def self.send_contact(contact)
    send_email(
      to: [
        {
          email: ENV.fetch("BREVO_SENDER"),
          name: "Admin"
        }
      ],
      subject: "New Contact Form Enquiry",
      html_content: <<~HTML,
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
      text_content: <<~TEXT
        New Contact Form Submission

        Name: #{contact.name}
        Email: #{contact.email}
        Mobile: #{contact.mobile}
        Subject: #{contact.subject}

        Message:
        #{contact.message}
      TEXT
    )
  end
end