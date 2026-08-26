class Admin::CoursesController < AdminController

  before_action :set_course,
                only: [:show, :edit, :update, :destroy]
       layout "admin"
             

  # ==================================================
  # INDEX
  # ==================================================

  def index
    @courses = Course.order(created_at: :desc)

    # Search
    if params[:search].present?
      @courses = @courses.where(
        "Course_name LIKE ?",
        "%#{params[:search]}%"
      )
    end

    # Status filter
    if params[:status].present?
      @courses = @courses.where(status: params[:status])
    end

    # Pagination
    @courses = @courses.page(params[:page]).per(10)

    # Statistics
    @total_courses = Course.count
    @active_courses = Course.where(status: "Active").count
    @inactive_courses = Course.where(status: "Inactive").count
  end

  # ==================================================
  # NEW
  # ==================================================

  def new
    @course = Course.new
  end

  # ==================================================
  # CREATE
  # ==================================================

  def create
    @course = Course.new(course_params)

    if @course.save
      redirect_to admin_courses_path,
                  notice: "Course created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # ==================================================
  # SHOW
  # ==================================================

  def show
  end

  # ==================================================
  # EDIT
  # ==================================================

  def edit
  end

  # ==================================================
  # UPDATE
  # ==================================================

  def update
    if @course.update(course_params)
      redirect_to admin_courses_path,
                  notice: "Course updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # ==================================================
  # DESTROY
  # ==================================================
def destroy
  @course = Course.find(params[:id])

  @course.destroy!

  redirect_to admin_courses_path,
              notice: "Course deleted successfully."
rescue ActiveRecord::InvalidForeignKey
  redirect_to admin_courses_path,
              alert: "This course cannot be deleted because it is still being used."
end

  # ==================================================
  # PRIVATE
  # ==================================================

  private

  def set_course
    @course = Course.find(params[:id])
  end

  def course_params
    params.require(:course).permit(
      :Course_name,
      :duration,
      :fee,
      :original_fee,
      :discount_percentage,
      :description,
      :learning_outcomes,
      :requirements,
      :teacher_id,
      :status,
      :course_type
    )
  end

end