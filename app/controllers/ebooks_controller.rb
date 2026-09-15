class EbooksController < ApplicationController

  # ==========================================================
  # E-BOOK LISTING
  # ==========================================================

  def index
    @ebooks =
      Ebook
        .published
        .includes(
          :ebook_files,
          cover_image_attachment: :blob
        )
        .order(
          published_at: :desc,
          created_at: :desc
        )

    @categories =
      Ebook
        .published
        .where.not(category: [nil, ""])
        .distinct
        .order(:category)
        .pluck(:category)

    # --------------------------------------------------------
    # SEARCH
    # --------------------------------------------------------

    if params[:q].present?
      search = "%#{params[:q].strip}%"

      @ebooks =
        @ebooks.where(
          "title ILIKE :search
           OR author ILIKE :search
           OR category ILIKE :search
           OR exam_name ILIKE :search",
          search: search
        )
    end

    # --------------------------------------------------------
    # CATEGORY FILTER
    # --------------------------------------------------------

    if params[:category].present?
      @ebooks =
        @ebooks.where(
          category: params[:category]
        )
    end
  end


  # ==========================================================
  # E-BOOK DETAIL
  # ==========================================================

def show
  @ebook =
    Ebook
      .published
      .includes(
        cover_image_attachment: :blob,
        ebook_files: {
          pdf_attachment: :blob
        }
      )
      .find(params[:id])

  @active_ebook_files =
    @ebook
      .ebook_files
      .select { |file| file.status == "active" }
end


  # ==========================================================
  # MY E-BOOKS
  # ==========================================================

  def my
    unless user_signed_in?
      redirect_to new_user_session_path,
                  alert: "Please login to view your E-Books."
      return
    end

    @purchases =
      current_user
        .ebook_purchases
        .paid
        .includes(
          ebook: {
            ebook_files: {
              pdf_attachment: :blob
            }
          }
        )
        .order(created_at: :desc)
  end


  # ==========================================================
  # E-BOOK ACCESS
  # ==========================================================
def access
  @ebook =
    Ebook
      .published
      .includes(
        ebook_files: {
          pdf_attachment: :blob
        }
      )
      .find(params[:id])

  # Load only active PDF/chapter files
  @ebook_files =
    @ebook
      .ebook_files
      .with_attached_pdf
      .where(status: "active")
      .order(:position, :id)

  # Remove files without an actual PDF
  @ebook_files =
    @ebook_files.select do |ebook_file|
      ebook_file.pdf.attached?
    end

  # Free E-Book
  return if @ebook.free?

  # Paid E-Book requires login
  unless user_signed_in?
    redirect_to new_user_session_path,
                alert: "Please login to access this E-Book."
    return
  end

  # Check successful purchase
  purchase =
    current_user
      .ebook_purchases
      .paid
      .find_by(ebook_id: @ebook.id)

  unless purchase
    redirect_to ebook_path(@ebook),
                alert: "You do not have access to this E-Book."
    return
  end
end

end