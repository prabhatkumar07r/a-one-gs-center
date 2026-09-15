class Admin::EbookFilesController < AdminController
  before_action :set_ebook
  before_action :set_ebook_file,
                only: [:edit, :update, :destroy]

 def index
  @ebook_files =
    @ebook
      .ebook_files
      .with_attached_pdf
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

    # New PDFs are always added at the end.
    # This prevents duplicate-position errors.
    @ebook_file.position = next_position

    if @ebook_file.pdf.blank?
      @ebook_file.errors.add(
        :pdf,
        "must be attached"
      )
    end

    if @ebook_file.errors.empty?
      if @ebook_file.save
        redirect_to admin_ebook_ebook_files_path(@ebook),
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
    new_position =
      ebook_file_params[:position].to_i

    new_position =
      @ebook_file.position if new_position <= 0

    begin
      EbookFile.transaction do
        if new_position != @ebook_file.position
          reorder_pdf(
            @ebook_file,
            new_position
          )
        end

        @ebook_file.update!(
          ebook_file_params.except(:position)
        )
      end

      redirect_to admin_ebook_ebook_files_path(@ebook),
                  notice: "PDF updated successfully."

    rescue ActiveRecord::RecordInvalid
      render :edit,
             status: :unprocessable_content
    end
  end

  def destroy
    EbookFile.transaction do
      @ebook_file.destroy!

      normalize_positions
    end

    redirect_to admin_ebook_ebook_files_path(@ebook),
                notice: "PDF deleted successfully."

  rescue ActiveRecord::RecordInvalid
    redirect_to admin_ebook_ebook_files_path(@ebook),
                alert: "PDF could not be deleted."
  end

  private

  def set_ebook
    @ebook =
      Ebook.find(params[:ebook_id])
  end

  def set_ebook_file
    @ebook_file =
      @ebook.ebook_files.find(params[:id])
  end

  def ebook_file_params
    params.require(:ebook_file).permit(
      :title,
      :description,
      :position,
      :status,
      :pdf
    )
  end

  def next_position
    @ebook
      .ebook_files
      .maximum(:position)
      .to_i + 1
  end

  # =========================================================
  # SAFE PDF REORDERING
  #
  # Because ebook_id + position is UNIQUE,
  # we first move every record to temporary
  # negative positions.
  # =========================================================

  def reorder_pdf(ebook_file, new_position)
    files =
      @ebook
        .ebook_files
        .order(:position, :id)
        .to_a

    files.delete(ebook_file)

    new_position =
      [[new_position, 1].max, files.length + 1].min

    files.insert(
      new_position - 1,
      ebook_file
    )

    # Temporary positions
    files.each_with_index do |file, index|
      file.update_column(
        :position,
        -(index + 1)
      )
    end

    # Final positions
    files.each_with_index do |file, index|
      file.update_column(
        :position,
        index + 1
      )
    end
  end

  # =========================================================
  # NORMALIZE POSITIONS AFTER DELETE
  # =========================================================

  def normalize_positions
    files =
      @ebook
        .ebook_files
        .order(:position, :id)
        .to_a

    # Temporary negative positions
    files.each_with_index do |file, index|
      file.update_column(
        :position,
        -(index + 1)
      )
    end

    # Final 1,2,3,4...
    files.each_with_index do |file, index|
      file.update_column(
        :position,
        index + 1
      )
    end
  end
end