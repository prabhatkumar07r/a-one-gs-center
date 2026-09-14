class EbookFilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_ebook_file
  before_action :verify_access!

  def show
    redirect_to rails_blob_path(
      @ebook_file.pdf,
      disposition: "inline"
    )
  end

  def download
    redirect_to rails_blob_path(
      @ebook_file.pdf,
      disposition: "attachment"
    )
  end

  private

  def set_ebook_file
    @ebook_file =
      EbookFile
        .includes(:ebook)
        .find(params[:id])
  end

  def verify_access!
    ebook = @ebook_file.ebook

    return render_access_denied unless
      @ebook_file.status == "active"

    return render_access_denied unless
      @ebook_file.pdf.attached?

    return if ebook.free?

    unless current_user
             .ebook_purchases
             .paid
             .exists?(ebook_id: ebook.id)

      render_access_denied
    end
  end

  def render_access_denied
    redirect_to ebook_path(@ebook_file.ebook),
                alert: "You do not have access to this PDF."
  end
end