class ContactsController < ApplicationController
  def create
    @contact = Contact.new(contact_params)

    if @contact.save
      begin
        Rails.logger.info "BREVO_LOGIN=#{ENV['BREVO_LOGIN']}"
        Rails.logger.info "BREVO_SENDER=#{ENV['BREVO_SENDER']}"
        Rails.logger.info "BREVO_KEY_PRESENT=#{ENV['BREVO_SMTP_KEY'].present?}"

        response = BrevoService.send_contact(@contact)

        if response.success?
          redirect_to sample_homepage_path,
                      notice: "Message sent successfully."
        else
          Rails.logger.error response.body

          redirect_to sample_homepage_path,
                      alert: "Email sending failed."
        end

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
    params.require(:contact).permit(
      :name,
      :email,
      :subject,
      :message
    )
  end
end