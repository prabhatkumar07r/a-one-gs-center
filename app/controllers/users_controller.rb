class UsersController < ApplicationController
  before_action :redirect_if_logged_in, only: [:new, :login]
    def students
    @students = User.student
  end

  def teachers
    @teachers = User.teacher
  end

  def new
    @user = User.new
  end

  def login
  end

  private

  def redirect_if_logged_in
    if logged_in?
      redirect_to "/home", notice: "You are already logged in"
    end
  end
end
