class Admin::EbooksController < AdminController

  before_action :set_ebook, only: [:show, :edit, :update, :destroy]

  def index
    @ebooks = Ebook.order(created_at: :desc)
  end

  def show
  end

  def new
    @ebook = Ebook.new
  end

  def create
    @ebook = Ebook.new(ebook_params)

    if @ebook.save
      redirect_to admin_ebook_path(@ebook),
                  notice: "E-Book created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @ebook.update(ebook_params)
      redirect_to admin_ebook_path(@ebook),
                  notice: "E-Book updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @ebook.destroy

    redirect_to admin_ebooks_path,
                notice: "E-Book deleted successfully."
  end

  private

  def set_ebook
    @ebook = Ebook.find(params[:id])
  end

  def ebook_params
    params.require(:ebook).permit(
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