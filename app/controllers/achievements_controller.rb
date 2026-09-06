class AchievementsController < ApplicationController
  before_action :authenticate_user!
  before_action :check_admin
  before_action :set_achievement, only: [:show, :edit, :update, :destroy]

  layout "admin"

  def index
    @achievements = Achievement.order(created_at: :desc)
  end

  def show
  end

  def new
  @achievement = Achievement.new
  @achievement.status = true
end

def create
  @achievement = Achievement.new(achievement_params)

  @achievement.status = true if @achievement.status.nil?

  if @achievement.save
    redirect_to achievements_path,
                notice: "Achievement created successfully."
  else
    render :new, status: :unprocessable_entity
  end
end

  def edit
  end

  def update
    if @achievement.update(achievement_params)
      redirect_to achievements_path,
                  notice: "Achievement updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @achievement.destroy
      redirect_to achievements_path,
                  notice: "Achievement deleted successfully."
    else
      redirect_to achievements_path,
                  alert: "Achievement could not be deleted."
    end
  end

  private

  def set_achievement
    @achievement = Achievement.find(params[:id])
  end

  def achievement_params
    params.require(:achievement).permit(
      :student_name,
      :title,
      :rank,
      :year,
      :description,
      :status,
      :photo,
      :video
    )
  end

  def check_admin
    unless current_user&.admin?
      redirect_to homepage_path,
                  alert: "Access Denied!"
    end
  end
end