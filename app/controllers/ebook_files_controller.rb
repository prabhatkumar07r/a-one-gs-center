class EbookFilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_ebook_file
  before_action :verify_access!

  # ==========================================================
  # READ PDF
  # ==========================================================

  def show
    redirect_to rails_blob_path(
      @ebook_file.pdf,
      disposition: "inline"
    )
  end


  # ==========================================================
  # DOWNLOAD PDF
  # ==========================================================

  def download
    redirect_to rails_blob_path(
      @ebook_file.pdf,
      disposition: "attachment"
    )
  end


  private


  # ==========================================================
  # FIND E-BOOK FILE
  # ==========================================================

  def set_ebook_file
    @ebook_file =
      EbookFile
        .includes(
          :ebook,
          pdf_attachment: :blob
        )
        .find(params[:id])
  end


  # ==========================================================
  # VERIFY PDF ACCESS
  # ==========================================================

  def verify_access!
    ebook = @ebook_file.ebook

    # --------------------------------------------------------
    # FILE MUST BE ACTIVE
    # --------------------------------------------------------

    unless @ebook_file.status == "active"
      render_access_denied
      return
    end


    # --------------------------------------------------------
    # PDF MUST EXIST
    # --------------------------------------------------------

    unless @ebook_file.pdf.attached?
      render_access_denied
      return
    end


    # --------------------------------------------------------
    # FREE E-BOOK
    # --------------------------------------------------------

    return if ebook.free?


    # --------------------------------------------------------
    # PAID E-BOOK
    # --------------------------------------------------------

    purchase =
      current_user
        .ebook_purchases
        .paid
        .find_by(ebook_id: ebook.id)

    unless purchase
      render_access_denied
      return
    end
  end


  # ==========================================================
  # ACCESS DENIED
  # ==========================================================

  def render_access_denied
    redirect_to ebook_path(@ebook_file.ebook),
                alert: "You do not have access to this PDF."
  end
end