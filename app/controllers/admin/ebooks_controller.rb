class Admin::EbooksController < AdminController

  before_action :set_ebook,
                only: [:show, :edit, :update, :destroy]


  # ========================================================
  # INDEX
  # ========================================================

  def index

    @ebooks =
      Ebook
        .order(created_at: :desc)

  end


  # ========================================================
  # SHOW
  # ========================================================

  def show
  end


  # ========================================================
  # NEW
  # ========================================================

  def new

    @ebook =
      Ebook.new

  end


  # ========================================================
  # CREATE
  # ========================================================

  def create

    @ebook =
      Ebook.new(ebook_params)

    if @ebook.save

      redirect_to admin_ebook_path(@ebook),
                  notice: "E-Book created successfully."

    else

      render :new,
             status: :unprocessable_entity

    end

  end


  # ========================================================
  # EDIT
  # ========================================================

  def edit
  end


  # ========================================================
  # UPDATE
  # ========================================================

  def update

    if @ebook.update(ebook_params)

      redirect_to admin_ebook_path(@ebook),
                  notice: "E-Book updated successfully."

    else

      render :edit,
             status: :unprocessable_entity

    end

  end


  # ========================================================
  # DESTROY
  # ========================================================

  def destroy

    @ebook.destroy

    redirect_to admin_ebooks_path,
                notice: "E-Book deleted successfully."

  end


  private


  # ========================================================
  # SET E-BOOK
  # ========================================================

  def set_ebook

    @ebook =
      Ebook
        .includes(
          cover_image_attachment: :blob,
          pdf_file_attachment: :blob,
          ebook_files: {
            pdf_attachment: :blob
          }
        )
        .find(params[:id])

  end


  # ========================================================
  # STRONG PARAMETERS
  # ========================================================

  def ebook_params

    params
      .require(:ebook)
      .permit(
        :title,
        :description,
        :author,
        :category,
        :language,
        :exam_name,
        :price,
        :original_price,
        :discount_percentage,
        :is_free,
        :status,
        :published_at,
        :cover_image,
        :pdf_file
      )

  end

end