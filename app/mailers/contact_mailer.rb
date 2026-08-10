class ContactMailer < ApplicationMailer
  default from: ENV["BREVO_SENDER"]

  def contact_email(contact)
    @contact = contact

    mail(
      to: ENV["BREVO_SENDER"],
      subject: "New Contact Form Enquiry"
    )
  end
end