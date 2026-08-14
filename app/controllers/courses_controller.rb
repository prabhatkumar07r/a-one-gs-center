class CoursesController < AdminController

  before_action :set_course,
                only: [:show, :edit, :update, :destroy]

  def index
    @courses = Course.order(created_at: :desc)

    if params[:search].present?
      @courses = @courses.where(
        "Course_name LIKE ?",
        "%#{params[:search]}%"
      )
    end

    if params[:status].present?
      @courses = @courses.where(status: params[:status])
    end

    @courses = @courses.page(params[:page]).per(10)

    @total_courses = Course.count
    @active_courses = Course.where(status: "Active").count
    @inactive_courses = Course.where(status: "Inactive").count
  end

  def class11
  end

  def class12
  end

  def Isc
  end

  def GeneralCompetitive
  end

  def new
    @course = Course.new
  end

  def create
    @course = Course.new(course_params)

    if @course.save
      redirect_to courses_path, notice: "Course created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if @course.update(course_params)
      redirect_to courses_path, notice: "Course updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @course.destroy

    redirect_to courses_path,
                notice: "Course deleted successfully"
  end

  def details
    @course = Course.find(params[:id])

    @videos = @course.videos.order(:position)

    @enrollment =
      current_user.enrollments.find_by(course: @course) if user_signed_in?

    @notes = Note
      .joins(:playlist)
      .where(playlists: { course_id: @course.id })
      .includes(:playlist)
  end

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
      :status
    )
  end

end