class ContactMailer < ApplicationMailer
  def contact_email(contact)
    @contact = contact

    mail(
      to: "prabhatkumar27032003@gmail.com",
      from: ENV["GMAIL_USERNAME"],
      subject: "New Contact Message"
    )
  end
end