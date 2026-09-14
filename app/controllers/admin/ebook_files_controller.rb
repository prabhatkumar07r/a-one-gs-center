class Admin::EbookFilesController < AdminController
  before_action :set_ebook
  before_action :set_ebook_file, only: [:edit, :update, :destroy]

  def index
    @ebook_files =
      @ebook
        .ebook_files
        .order(:position, :id)
  end

  def new
    @ebook_file =
      @ebook.ebook_files.new(
        position: next_position,
        status: "active"
      )
  end

  def create
    @ebook_file =
      @ebook.ebook_files.new(ebook_file_params)

    if @ebook_file.pdf.blank?
      @ebook_file.errors.add(:pdf, "must be attached")
    end

    if @ebook_file.errors.empty?
      assign_safe_position

      if @ebook_file.save
        normalize_positions

        redirect_to admin_ebook_path(@ebook),
                    notice: "PDF added successfully."
      else
        render :new,
               status: :unprocessable_content
      end
    else
      render :new,
             status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    @ebook_file.assign_attributes(ebook_file_params)

    if @ebook_file.save
      normalize_positions

      redirect_to admin_ebook_path(@ebook),
                  notice: "PDF updated successfully."
    else
      render :edit,
             status: :unprocessable_content
    end
  end

  def destroy
    @ebook_file.destroy!

    normalize_positions

    redirect_to admin_ebook_path(@ebook),
                notice: "PDF deleted successfully."
  end

  private

  def set_ebook
    @ebook = Ebook.find(params[:ebook_id])
  end

  def set_ebook_file
    @ebook_file =
      @ebook
        .ebook_files
        .find(params[:id])
  end

  def ebook_file_params
    params
      .require(:ebook_file)
      .permit(
        :title,
        :description,
        :position,
        :status,
        :pdf
      )
  end

  def next_position
    @ebook.ebook_files.maximum(:position).to_i + 1
  end

  def assign_safe_position
    desired_position = @ebook_file.position.to_i

    desired_position = next_position if desired_position <= 0

    @ebook_file.position = desired_position
  end

  def normalize_positions
    files =
      @ebook
        .ebook_files
        .order(:position, :id)

    files.each_with_index do |file, index|
      correct_position = index + 1

      next if file.position == correct_position

      file.update_column(
        :position,
        correct_position
      )
    end
  end
end