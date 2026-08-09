class ContactsController < ApplicationController
  def create
    @contact = Contact.new(contact_params)

    if @contact.save
      begin
        ContactMailer.contact_email(@contact).deliver_now
        redirect_to sample_homepage_path, notice: "Message sent successfully."
      rescue => e
        Rails.logger.error "=============================="
        Rails.logger.error e.class
        Rails.logger.error e.message
        Rails.logger.error e.backtrace.join("\n")
        Rails.logger.error "=============================="

        redirect_to sample_homepage_path,
                    alert: "Email failed: #{e.class}"
      end
    else
      redirect_to sample_homepage_path,
                  alert: "Message could not be sent."
    end
  end

  private

  def contact_params
    params.require(:contact).permit(:name, :email, :subject, :message)
  end
end