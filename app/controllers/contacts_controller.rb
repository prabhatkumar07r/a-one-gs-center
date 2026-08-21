class ContactsController < ApplicationController
  def create
  @contact = Contact.new(contact_params)

  if @contact.save
    begin
      Rails.logger.info "BREVO_LOGIN=#{ENV['BREVO_LOGIN']}"
      Rails.logger.info "BREVO_SENDER=#{ENV['BREVO_SENDER']}"
      Rails.logger.info "BREVO_API_KEY_PRESENT=#{ENV['BREVO_API_KEY'].present?}"

      response = BrevoService.send_contact(@contact)

      Rails.logger.info "Brevo Status: #{response.code}"
      Rails.logger.info "Brevo Body: #{response.body}"

      if [200, 201, 202].include?(response.code.to_i)
        redirect_to sample_homepage_path,
                    notice: "Message sent successfully."
      else
        Rails.logger.error response.body

        redirect_to sample_homepage_path,
                    alert: "Email sending failed."
      end

    rescue => e
      Rails.logger.error e.class
      Rails.logger.error e.message
      Rails.logger.error e.backtrace.join("\n")

      redirect_to sample_homepage_path,
                  alert: "Email failed: #{e.message}"
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
      :mobile,
      :subject,
      :message
    )
  end
end