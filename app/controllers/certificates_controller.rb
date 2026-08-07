class CertificatesController < ApplicationController
  before_action :authenticate_user!

  def index
    @certificates = current_user.certificates.includes(:course)
  end

  def show
  @certificate = current_user.certificates.find(params[:id])

  respond_to do |format|
    format.html

    format.pdf do
      pdf = CertificatePdf.new(@certificate)

      send_data pdf.render,
                filename: "certificate.pdf",
                type: "application/pdf",
                disposition: "inline"
    end
  end
end
end
