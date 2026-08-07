class AttendancesController < ApplicationController
    before_action :authenticate_user!
  before_action :allow_admin_or_teacher

  def index

    @attendances = Attendance.includes(:user, :course)

    if params[:search].present?
           @attendances = @attendances.joins(:user)
                             .where("users.name LIKE ?",
                                    "%#{params[:search]}%")
    end

    @total_attendance = Attendance.count
    @present = Attendance.where(status: "Present").count
    @absent = Attendance.where(status: "Absent").count
    @leave = Attendance.where(status: "Leave").count
  end

  def new
    @attendance = Attendance.new
  end
  def show
  @attendance = Attendance.find(params[:id])
end

def edit
  @attendance = Attendance.find(params[:id])
end

def update
  @attendance = Attendance.find(params[:id])

  if @attendance.update(attendance_params)
    redirect_to attendances_path,
    notice: "Attendance Updated Successfully."
  else
    render :edit
  end
end

def destroy
  @attendance = Attendance.find(params[:id])
  @attendance.destroy

  redirect_to attendances_path,
  notice: "Attendance Deleted Successfully."
end

  def create
    @attendance = Attendance.new(attendance_params)

    if @attendance.save
      redirect_to attendances_path, notice: "Attendance Added Successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

def allow_admin_or_teacher
  unless current_user.admin? || current_user.teacher?
    redirect_to root_path, alert: "Access Denied"
  end
end

  def attendance_params
    params.require(:attendance).permit(
      :user_id,
      :course_id,
      :date,
      :status
    )
  end
end
