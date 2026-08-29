class AttendancesController < AdminController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_attendance, only: [:show]

  def index
    @attendances = Attendance
      .includes(:user, :course)
      .order(date: :desc, created_at: :desc)

    # COURSE FILTER
    if params[:course_id].present?
      @attendances =
        @attendances.where(course_id: params[:course_id])
    end

    # STUDENT FILTER
    if params[:student_id].present?
      @attendances =
        @attendances.where(user_id: params[:student_id])
    end

    # STATUS FILTER
    if params[:status].present?
      @attendances =
        @attendances.where(status: params[:status])
    end

    # DATE FILTER
    if params[:date].present?
      @attendances =
        @attendances.where(date: params[:date])
    end

    # SEARCH STUDENT
    if params[:search].present?
      @attendances =
        @attendances
          .joins(:user)
          .where(
            "users.name ILIKE ?",
            "%#{params[:search]}%"
          )
    end

    # DROPDOWN DATA
    @courses = Course.order(:Course_name)

    @students = User
      .where(role: "student")
      .order(:name)

    # STATISTICS
    @total_attendance = @attendances.count

    @present =
      @attendances.where(status: "Present").count

    @absent =
      @attendances.where(status: "Absent").count

    @leave =
      @attendances.where(status: "Leave").count
  end

  def show
  end

  private

  def set_attendance
    @attendance = Attendance
      .includes(:user, :course)
      .find(params[:id])
  end
end