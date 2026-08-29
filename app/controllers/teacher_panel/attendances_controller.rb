class TeacherPanel::AttendancesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_teacher
  before_action :set_course
  before_action :set_attendance,
                only: [:show, :edit, :update, :destroy]

     layout "teacher"             


  # =========================================================
  # INDEX
  # =========================================================

  def index

    @attendances = @course.attendances
                          .includes(:user)
                          .order(date: :desc, created_at: :desc)

    # -------------------------------------------------------
    # SEARCH
    # -------------------------------------------------------

    if params[:search].present?

      @attendances = @attendances
        .joins(:user)
        .where(
          "users.name LIKE ?",
          "%#{params[:search]}%"
        )

    end


    # -------------------------------------------------------
    # STATUS FILTER
    # -------------------------------------------------------

    if params[:status].present?

      @attendances =
        @attendances.where(status: params[:status])

    end


    # -------------------------------------------------------
    # STATISTICS
    # -------------------------------------------------------

    @total_attendance = @attendances.count

    @present =
      @attendances.where(status: "Present").count

    @absent =
      @attendances.where(status: "Absent").count

    @leave =
      @attendances.where(status: "Leave").count

  end


  # =========================================================
  # NEW
  # =========================================================

  def new

    @attendance = @course.attendances.new(
      date: Date.current,
      status: "Present"
    )

    load_enrolled_students

  end


  # =========================================================
  # CREATE
  # =========================================================

  def create

    @attendance =
      @course.attendances.new(attendance_params)

    # -------------------------------------------------------
    # SECURITY
    # -------------------------------------------------------

    enrollment = Enrollment.find_by(
      user_id: attendance_params[:user_id],
      course_id: @course.id
    )

    unless enrollment

      @attendance.errors.add(
        :user_id,
        "is not enrolled in this course"
      )

      load_enrolled_students

      render :new,
             status: :unprocessable_entity

      return

    end


    # -------------------------------------------------------
    # SAVE
    # -------------------------------------------------------

    if @attendance.save

      redirect_to teacher_panel_course_attendances_path(@course),
                  notice: "Attendance added successfully."

    else

      load_enrolled_students

      render :new,
             status: :unprocessable_entity

    end

  end


  # =========================================================
  # SHOW
  # =========================================================

  def show

  end


  # =========================================================
  # EDIT
  # =========================================================

  def edit

    load_enrolled_students

  end


  # =========================================================
  # UPDATE
  # =========================================================

  def update

    # -------------------------------------------------------
    # Verify student enrollment
    # -------------------------------------------------------

    enrollment = Enrollment.find_by(
      user_id: attendance_params[:user_id],
      course_id: @course.id
    )

    unless enrollment

      @attendance.errors.add(
        :user_id,
        "is not enrolled in this course"
      )

      load_enrolled_students

      render :edit,
             status: :unprocessable_entity

      return

    end


    # -------------------------------------------------------
    # Update
    # -------------------------------------------------------

    if @attendance.update(attendance_params.except(:course_id))

      redirect_to teacher_panel_course_attendances_path(@course),
                  notice: "Attendance updated successfully."

    else

      load_enrolled_students

      render :edit,
             status: :unprocessable_entity

    end

  end


  # =========================================================
  # DESTROY
  # =========================================================

  def destroy

    @attendance.destroy

    redirect_to teacher_panel_course_attendances_path(@course),
                notice: "Attendance deleted successfully."

  end


  private


  # =========================================================
  # REQUIRE TEACHER
  # =========================================================

  def require_teacher

    unless current_user.teacher?

      redirect_to root_path,
                  alert: "Access Denied."

    end

  end


  # =========================================================
  # SET COURSE
  # =========================================================

  def set_course

    @course = current_user.teacher.courses.find(
      params[:course_id]
    )

  rescue ActiveRecord::RecordNotFound

    redirect_to teacher_panel_courses_path,
                alert: "You do not have access to this course."

  end


  # =========================================================
  # SET ATTENDANCE
  # =========================================================

  def set_attendance

    @attendance = @course.attendances.find(
      params[:id]
    )

  rescue ActiveRecord::RecordNotFound

    redirect_to teacher_panel_course_attendances_path(@course),
                alert: "Attendance record not found."

  end


  # =========================================================
  # LOAD ENROLLED STUDENTS
  # =========================================================

  def load_enrolled_students

    @students =
      User
        .where(role: "student")
        .where(
          id: Enrollment
            .where(course_id: @course.id)
            .select(:user_id)
        )
        .order(:name)

  end


  # =========================================================
  # STRONG PARAMETERS
  # =========================================================

  def attendance_params

    params.require(:attendance).permit(
      :user_id,
      :course_id,
      :date,
      :status
    )

  end

end