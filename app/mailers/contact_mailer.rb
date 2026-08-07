class ContactMailer < ApplicationMailer
  def contact_email(contact)
    @contact = contact

    mail(
      to: "prabhatkumar270320003@gmail.com",
      subject: "New Contact Message"
    )
  end
end
