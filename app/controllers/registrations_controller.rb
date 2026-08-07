class RegistrationsController < ApplicationController
 before_action :authenticate_user!
 before_action :require_admin

  def index
    @students = Student.order(created_at: :asc)

    if params[:search].present?
      keyword = "%#{params[:search]}%"

      @students = @students.where(
        "name LIKE ? OR email LIKE ? OR mobile LIKE ?",
        keyword,
        keyword,
        keyword
      )
    end

    @students = @students.page(params[:page]).per(10)

    @total_students = Student.count
  end

  def show
    @student = Student.find(params[:id])
  end

  def edit
    @student = Student.find(params[:id])
  end

  def update
    @student = Student.find(params[:id])

    if @student.update(students_params)
      redirect_to registrations_path, notice: "Student updated successfully."
    else
      render :edit
    end
  end

  def destroy
    @student = Student.find(params[:id])
    @student.destroy

    redirect_to registrations_path,
                notice: "Student deleted successfully."
  end

  private

  def students_params
    params.require(:student).permit(
      :name,
      :email,
      :mobile
    )
  end
  def admin_demo_params
    params.require(:demo).permit(:status)
  end
  private

  def require_admin
  unless current_user.admin?
    redirect_to homepage_path,
                alert: "Access Denied!"
  end
end
end
