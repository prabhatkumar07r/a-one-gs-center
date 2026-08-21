require "net/http"
require "json"

class BrevoService
  API_URL = "https://api.brevo.com/v3/smtp/email"

  def self.send_contact(contact)
    uri = URI(API_URL)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 30
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)

    request["accept"] = "application/json"
    request["content-type"] = "application/json"
    request["api-key"] = ENV.fetch("BREVO_API_KEY")

    request.body = {
      sender: {
        name: "A-One GS Center",
        email: ENV.fetch("BREVO_SENDER")
      },

      to: [
        {
          email: ENV.fetch("BREVO_SENDER"),
          name: "Admin"
        }
      ],

      replyTo: {
        email: contact.email,
        name: contact.name
      },

      subject: "New Contact Form Enquiry",

      htmlContent: <<~HTML
        <h2>New Contact Form Submission</h2>

        <p>
          <strong>Name:</strong> #{contact.name}
        </p>

        <p>
          <strong>Email:</strong> #{contact.email}
        </p>

        <p>
          <strong>Mobile:</strong> #{contact.mobile}
        </p>

        <p>
          <strong>Subject:</strong> #{contact.subject}
        </p>

        <p>
          <strong>Message:</strong>
        </p>

        <p>
          #{contact.message}
        </p>
      HTML
    }.to_json

    response = http.request(request)

    Rails.logger.info "Brevo Status: #{response.code}"
    Rails.logger.info "Brevo Response: #{response.body}"

    response
  end
end