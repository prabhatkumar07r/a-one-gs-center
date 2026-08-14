class BatchesController < AdminController
  before_action :set_batch, only: [:show, :edit, :update, :destroy]

  def index
    @batches = Batch.includes(:course, :teacher).order(created_at: :desc)
  end

  def show
  end

  def new
    @batch = Batch.new
  end

  def create
    @batch = Batch.new(batch_params)

    if @batch.save
      redirect_to batches_path, notice: "Batch created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @batch.update(batch_params)
      redirect_to batches_path, notice: "Batch updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @batch.destroy
    redirect_to batches_path, notice: "Batch deleted successfully."
  end

  private

  def set_batch
    @batch = Batch.find(params[:id])
  end

  def batch_params
    params.require(:batch).permit(
      :batch_name,
      :course_id,
      :teacher_id,
      :start_date,
      :end_date,
      :timing,
      :room_no,
      :status
    )
  end
end