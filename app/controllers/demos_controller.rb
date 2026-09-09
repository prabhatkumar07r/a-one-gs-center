class DemosController < AdminController
  before_action :authenticate_user!
  before_action :require_admin

  def index
  @demos = Demo.order(created_at: :desc)

  # Search: Name OR Phone OR Email
  if params[:search].present?
    keyword = "%#{params[:search]}%"

    @demos = @demos.where(
      "name ILIKE :keyword OR phone ILIKE :keyword OR email ILIKE :keyword",
      keyword: keyword
    )
  end

  # Status filter
  if params[:status].present?
    @demos = @demos.where(status: params[:status])
  end

  # Pagination
  @demos = @demos.page(params[:page]).per(10)

  # Statistics
  @total_demos = Demo.count
  @pending     = Demo.where(status: "Pending").count
  @contacted   = Demo.where(status: "Contacted").count
  @enrolled    = Demo.where(status: "Enrolled").count
  @rejected    = Demo.where(status: "Rejected").count

  # Charts
  @status_chart = Demo.group(:status).count
  @course_chart = Demo.group(:course).count
end

  def show
    @demo = Demo.find(params[:id])
  end

  def edit
    @demo = Demo.find(params[:id])
    @courses = Course.order(created_at: :desc)
  end

  def update
    @demo = Demo.find(params[:id])

    if @demo.update(admin_demo_params)
      redirect_to demos_path,
                  notice: "Demo request updated successfully."
    else
      @courses = Course.order(created_at: :desc)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @demo = Demo.find(params[:id])
    @demo.destroy

    redirect_to demos_path,
                notice: "Demo request deleted successfully."
  end

  def export
    @demos = Demo.order(created_at: :desc)

    respond_to do |format|
      format.xlsx
    end
  end

  private

  def admin_demo_params
    params.require(:demo).permit(
      :name,
      :phone,
      :email,
      :course,
      :batch,
      :city,
      :preferred_time,
      :status
    )
  end

  def require_admin
    redirect_to homepage_path,
                alert: "Access Denied!" unless current_user.admin?
  end
end