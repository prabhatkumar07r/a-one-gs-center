class TeachersController < ApplicationController

  def index
    @teachers = Teacher.order(created_at: :asc)

    if params[:search].present?
      @teachers = @teachers.where(
        "name LIKE ? OR email LIKE ? OR mobile LIKE ?",
        "%#{params[:search]}%",
        "%#{params[:search]}%",
        "%#{params[:search]}%"
      )
    end

    @total_teachers = Teacher.count
    @active_teachers = Teacher.where(status: "Active").count
    @inactive_teachers = Teacher.where(status: "Inactive").count
  end

  def new
    @teacher = Teacher.new
  end

  def create
    @teacher = Teacher.new(teacher_params)

    if @teacher.save
      redirect_to teachers_path, notice: "Teacher Added Successfully"
    else
      render :new
    end
  end

  def show
    @teacher = Teacher.find(params[:id])
  end

  def edit
    @teacher = Teacher.find(params[:id])
  end

  def update
    @teacher = Teacher.find(params[:id])

    if @teacher.update(teacher_params)
      redirect_to teachers_path, notice: "Teacher Updated Successfully"
    else
      render :edit
    end
  end

  def destroy
    @teacher = Teacher.find(params[:id])
    @teacher.destroy

    redirect_to teachers_path, notice: "Teacher Deleted Successfully"
  end

  private

  def teacher_params
  params.require(:teacher).permit(
    :name,
    :email,
    :mobile,
    :qualification,
    :subject,
    :experience,
    :salary,
    :joining_date,
    :status,
    :designation,
    :bio,
    :facebook,
    :instagram,
    :linkedin,
    :gmail,
    :photo
  )
end
end