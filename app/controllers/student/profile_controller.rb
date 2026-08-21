class Student::ProfileController < ApplicationController
  before_action :authenticate_user!
  before_action :require_student

  def show
    @student = current_user
    @courses = current_user.enrollments.includes(:course).map(&:course)

    @total_courses = @courses.count
    @completed_courses = 0
    @lectures_done = 0
    @total_modules = @courses.sum do |course|
      course.respond_to?(:videos) ? course.videos.count : 0
    end
  end

  def edit
    @student = current_user
  end

  def update
    @student = current_user

    if @student.update(profile_params)
      redirect_to student_profile_path,
                  notice: "Profile updated successfully."
    else
      flash.now[:alert] = @student.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def password
    @student = current_user
  end

  def change_password
    @student = current_user

    unless @student.valid_password?(params[:current_password])
      redirect_to student_profile_password_path,
                  alert: "Current password is incorrect."
      return
    end

    if params[:password].blank?
      redirect_to student_profile_password_path,
                  alert: "New password cannot be blank."
      return
    end

    if params[:password] != params[:password_confirmation]
      redirect_to student_profile_password_path,
                  alert: "New password and confirmation do not match."
      return
    end

    if @student.update(
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    )
      redirect_to student_profile_path,
                  notice: "Password changed successfully."
    else
      redirect_to student_profile_password_path,
                  alert: @student.errors.full_messages.to_sentence
    end
  end

  private

  def profile_params
    params.require(:user).permit(
      :name,
      :email,
      :mobile,
      :image
    )
  end

  def require_student
    unless current_user.present?
      redirect_to root_path, alert: "Student access required."
    end
  end
end