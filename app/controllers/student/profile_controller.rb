class Student::ProfileController < ApplicationController
  before_action :authenticate_user!
  before_action :require_student

  # =========================================================
  # SHOW PROFILE
  # =========================================================

  def show
    @student = current_user

    # =======================================================
    # COURSES
    # =======================================================

    @courses =
      current_user
        .enrollments
        .includes(:course)
        .map(&:course)
        .compact
        .uniq

    @total_courses = @courses.count

    # -------------------------------------------------------
    # COURSE STATISTICS
    # -------------------------------------------------------

    @completed_courses = 0
    @lectures_done = 0

    @total_modules =
      @courses.sum do |course|
        course.respond_to?(:videos) ? course.videos.count : 0
      end


    # =======================================================
    # TEST SERIES
    # =======================================================

    @test_series_purchases =
      current_user
        .test_series_purchases
        .where(
          payment_status: "paid",
          status: "Active"
        )
        .includes(
          test_series: :test_series_tests
        )
        .order(created_at: :desc)

    @my_test_series =
      @test_series_purchases
        .map(&:test_series)
        .compact
        .uniq

    @total_test_series =
      @my_test_series.count


    # =======================================================
    # TEST SERIES STATISTICS
    # =======================================================

    @completed_test_series_tests =
      current_user
        .test_series_attempts
        .where(status: "Completed")
        .count


    # =======================================================
    # TOTAL LECTURES
    # =======================================================

    @total_lectures =
      @courses.sum do |course|
        course.respond_to?(:videos) ? course.videos.count : 0
      end
  end


  # =========================================================
  # EDIT PROFILE
  # =========================================================

  def edit
    @student = current_user
  end


  # =========================================================
  # UPDATE PROFILE
  # =========================================================

  def update
    @student = current_user

    if @student.update(profile_params)

      redirect_to student_profile_path,
                  notice: "Profile updated successfully."

    else

      flash.now[:alert] =
        @student.errors.full_messages.to_sentence

      render :edit,
             status: :unprocessable_entity
    end
  end


  # =========================================================
  # PASSWORD PAGE
  # =========================================================

  def password
    @student = current_user
  end


  # =========================================================
  # CHANGE PASSWORD
  # =========================================================

  def change_password
    @student = current_user

    # -------------------------------------------------------
    # CURRENT PASSWORD
    # -------------------------------------------------------

    unless @student.valid_password?(params[:current_password])

      redirect_to student_profile_password_path,
                  alert: "Current password is incorrect."

      return
    end


    # -------------------------------------------------------
    # NEW PASSWORD
    # -------------------------------------------------------

    if params[:password].blank?

      redirect_to student_profile_password_path,
                  alert: "New password cannot be blank."

      return
    end


    # -------------------------------------------------------
    # CONFIRM PASSWORD
    # -------------------------------------------------------

    if params[:password] != params[:password_confirmation]

      redirect_to student_profile_password_path,
                  alert: "New password and confirmation do not match."

      return
    end


    # -------------------------------------------------------
    # UPDATE PASSWORD
    # -------------------------------------------------------

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


  # =========================================================
  # PROFILE PARAMS
  # =========================================================

  def profile_params
    params.require(:user).permit(
      :name,
      :email,
      :mobile,
      :image
    )
  end


  # =========================================================
  # STUDENT ACCESS
  # =========================================================

  def require_student
    unless current_user.present?

      redirect_to root_path,
                  alert: "Student access required."

    end
  end

end