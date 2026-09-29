# app/services/brevo_payment_notification_service.rb

require "net/http"
require "uri"
require "json"

class BrevoPaymentNotificationService

  BREVO_EMAIL_URL =
    "https://api.brevo.com/v3/smtp/email"

  BREVO_WHATSAPP_URL =
    "https://api.brevo.com/v3/whatsapp/sendMessage"

  # =========================================================
  # PAYMENT SUCCESS EMAIL
  # =========================================================

  def self.send_success_email(payment)
    new(payment).send_success_email
  end



  # =========================================================
  # PAYMENT REMINDER EMAIL
  # =========================================================

  def self.send_reminder_email(
    payment,
    additional_email: nil
  )
    new(payment).send_reminder_email(
      additional_email: additional_email
    )
  end

  # =========================================================
  # PAYMENT REMINDER WHATSAPP
  # =========================================================

  def self.send_reminder_whatsapp(payment)
    new(payment).send_reminder_whatsapp
  end

  # =========================================================
  # INITIALIZE
  # =========================================================

  def initialize(payment)
    @payment = payment

    @enrollment = payment.enrollment
    @student = @enrollment.user
    @course = @enrollment.course
  end

  # =========================================================
  # SUCCESS EMAIL
  # =========================================================

  def send_success_email
    email = @student.email.to_s.strip

    raise "Student email is missing." if email.blank?

    subject =
      "Payment Successful – #{@course.Course_name}"

    html_content = <<~HTML
      <div style="font-family:Arial,sans-serif;line-height:1.6;color:#222;">

        <h2 style="color:#8009e2;">
          Payment Successful
        </h2>

        <p>
          Hello #{@student.name},
        </p>

        <p>
          A One GS Center की तरफ से आपको सूचित किया जाता है कि
          आपका payment successfully receive हो गया है।
        </p>

        <p>
          <strong>Course:</strong>
          #{@course.Course_name}
        </p>

        <p>
          <strong>Payment ID:</strong>
          #{@payment.id}
        </p>

        <p>
          <strong>Amount:</strong>
          ₹#{@payment.amount}
        </p>

        <p>
          आपका enrollment अब approved है और आप course access कर सकते हैं।
        </p>

        <p>
          <strong>Regards,</strong><br>
          A One GS Center<br>
          Professor Colony, Gali No. 01<br>
          Bara Chakia, East Champaran, Bihar<br>
          Email: supportaonegscenter@gmail.com
        </p>

      </div>
    HTML

    payload = {
      sender: {
        name: ENV.fetch(
          "BREVO_SENDER_NAME",
          "A One GS Center"
        ),
        email: ENV.fetch(
          "BREVO_SENDER_EMAIL",
          "supportaonegscenter@gmail.com"
        )
      },
      to: [
        {
          email: email,
          name: @student.name
        }
      ],
      subject: subject,
      htmlContent: html_content
    }

    send_brevo_request(
      BREVO_EMAIL_URL,
      payload
    )
  end

 

  # =========================================================
  # PAYMENT REMINDER EMAIL
  # =========================================================

  def send_reminder_email(additional_email: nil)
    primary_email =
      @student.email.to_s.strip

    raise "Student email is missing." if primary_email.blank?

    recipients = [
      {
        email: primary_email,
        name: @student.name
      }
    ]

    additional_email =
      additional_email.to_s.strip

    if additional_email.present? &&
       additional_email.downcase != primary_email.downcase

      recipients << {
        email: additional_email
      }
    end

    subject =
      "Payment Reminder – #{@course.Course_name}"

    html_content = <<~HTML
      <div style="font-family:Arial,sans-serif;line-height:1.6;color:#222;">

        <p>
          Hello #{@student.name},
        </p>

        <p>
          A One GS Center की तरफ से यह payment reminder है।
        </p>

        <p>
          आपने <strong>#{@course.Course_name}</strong>
          के लिए enrollment किया है, लेकिन आपका payment
          अभी तक complete नहीं हुआ है।
        </p>

        <p>
          कृपया अपना payment complete कर दें ताकि आपका
          course access activate किया जा सके।
        </p>

        <p>
          अगर payment करने में किसी भी प्रकार की समस्या आ रही है,
          तो कृपया हमें बताएं। हमारी team आपकी सहायता करने के लिए
          उपलब्ध है।
        </p>

        <p>
          Regards,<br>
          A One GS Center<br>
          Professor Colony, Gali No. 01<br>
          Bara Chakia, East Champaran, Bihar<br>
          Email: supportaonegscenter@gmail.com
        </p>

      </div>
    HTML

    payload = {
      sender: {
        name: ENV.fetch(
          "BREVO_SENDER_NAME",
          "A One GS Center"
        ),
        email: ENV.fetch(
          "BREVO_SENDER_EMAIL",
          "supportaonegscenter@gmail.com"
        )
      },
      to: recipients,
      subject: subject,
      htmlContent: html_content
    }

    send_brevo_request(
      BREVO_EMAIL_URL,
      payload
    )
  end

  # =========================================================
  # PAYMENT REMINDER WHATSAPP
  # =========================================================

  def send_reminder_whatsapp
    phone = student_phone

    raise "Student WhatsApp number is missing." if phone.blank?

    template_id =
      ENV["BREVO_PAYMENT_REMINDER_WHATSAPP_TEMPLATE_ID"].to_s.strip

    raise "Brevo WhatsApp reminder template is not configured." if template_id.blank?

    payload = {
      contactNumbers: phone,
      templateId: template_id,
      params: [
        @student.name.to_s,
        @course.Course_name.to_s
      ]
    }

    send_brevo_request(
      BREVO_WHATSAPP_URL,
      payload
    )
  end

  private

  # =========================================================
  # STUDENT PHONE
  # =========================================================

  def student_phone
    if @student.respond_to?(:phone)
      @student.phone.to_s.strip
    elsif @student.respond_to?(:mobile)
      @student.mobile.to_s.strip
    else
      ""
    end
  end

  # =========================================================
  # BREVO REQUEST
  # =========================================================

  def send_brevo_request(url, payload)
    api_key =
      ENV.fetch("BREVO_API_KEY")

    uri = URI.parse(url)

    request =
      Net::HTTP::Post.new(uri)

    request["accept"] =
      "application/json"

    request["content-type"] =
      "application/json"

    request["api-key"] =
      api_key

    request.body =
      JSON.generate(payload)

    http =
      Net::HTTP.new(
        uri.host,
        uri.port
      )

    http.use_ssl = true

    response =
      http.request(request)

    unless response.is_a?(
      Net::HTTPSuccess
    )
      raise(
        "Brevo API error #{response.code}: #{response.body}"
      )
    end

    JSON.parse(response.body)
  rescue JSON::ParserError
    {
      "success" => true,
      "raw_response" => response.body
    }
  end
end