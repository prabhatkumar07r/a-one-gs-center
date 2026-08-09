class ContactsController < ApplicationController
  def create
    @contact = Contact.new(contact_params)

    if @contact.save
      Rails.logger.info "GMAIL_USERNAME=#{ENV['GMAIL_USERNAME'].inspect}"
      Rails.logger.info "GMAIL_APP_PASSWORD_PRESENT=#{ENV['GMAIL_APP_PASSWORD'].present?}"

      ContactMailer.contact_email(@contact).deliver_now

      redirect_to sample_homepage_path,
                  notice: "Message sent successfully."
    else
      redirect_to sample_homepage_path,
                  alert: "Message could not be sent."
    end
  end

  private

  def contact_params
    params.require(:contact).permit(
      :name,
      :email,
      :subject,
      :message
    )
  end
end