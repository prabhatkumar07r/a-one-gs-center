class StudentsController < ApplicationController

  def index
    @students = User.where(role: "student")
                    .order(created_at: :desc)
                    .page(params[:page])
                    .per(10)
  end

  def show
    @student = User.find(params[:id])
  end

  def new
    @student = User.new
  end

  def create
    @student = User.new(student_params)
    @student.role = "student"

    if @student.save
      redirect_to students_path, notice: "Student created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
  end

  def destroy
  end


  private

  def student_params
    params.require(:user).permit(
      :name,
      :email,
      :mobile,
      :password,
      :age
    )
  end

end