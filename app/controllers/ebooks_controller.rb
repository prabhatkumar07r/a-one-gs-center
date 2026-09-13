class EbooksController < ApplicationController
  def index
    @ebooks = Ebook.published
                   .order(published_at: :desc, created_at: :desc)

    if params[:q].present?
      search = "%#{params[:q].strip}%"

      @ebooks = @ebooks.where(
        "title ILIKE :search
         OR author ILIKE :search
         OR category ILIKE :search
         OR exam_name ILIKE :search",
        search: search
      )
    end

    if params[:category].present?
      @ebooks = @ebooks.where(category: params[:category])
    end
  end

  def show
    @ebook = Ebook.published.find(params[:id])
  end

  # ==========================================================
  # READ / DOWNLOAD E-BOOK
  # ==========================================================

  def download
    @ebook = Ebook.published.find(params[:id])

    # --------------------------------------------------------
    # PDF CHECK
    # --------------------------------------------------------

    unless @ebook.pdf_file.attached?
      redirect_to ebook_path(@ebook),
                  alert: "E-Book PDF is not available yet."
      return
    end

    # --------------------------------------------------------
    # PAID E-BOOK SECURITY
    # --------------------------------------------------------

    if @ebook.paid?

      unless user_signed_in?
        redirect_to new_user_session_path,
                    alert: "Please login to access this E-Book."
        return
      end

      purchase = current_user.ebook_purchases
                             .paid
                             .find_by(ebook_id: @ebook.id)

      unless purchase
        redirect_to ebook_path(@ebook),
                    alert: "Please purchase this E-Book to access the PDF."
        return
      end
    end

    # --------------------------------------------------------
    # READ vs DOWNLOAD
    # --------------------------------------------------------

    disposition =
      params[:download].to_s == "true" ? "attachment" : "inline"

    send_data @ebook.pdf_file.download,
              filename: "#{@ebook.title.parameterize}.pdf",
              type: @ebook.pdf_file.content_type.presence || "application/pdf",
              disposition: disposition

  rescue ActiveRecord::RecordNotFound
    redirect_to ebooks_path,
                alert: "E-Book not found."

  rescue ActiveStorage::FileNotFoundError
    redirect_to ebook_path(@ebook),
                alert: "E-Book PDF file could not be found."

  rescue StandardError => e
    Rails.logger.error(
      "EBOOK PDF ACCESS ERROR: #{e.class} - #{e.message}"
    )

    redirect_to ebook_path(@ebook),
                alert: "Unable to open the E-Book right now."
  end
end