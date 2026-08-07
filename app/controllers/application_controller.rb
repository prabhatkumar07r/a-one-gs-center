class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :authenticate_user!

  protected

  def after_sign_in_path_for(resource)
    if resource.admin?
      dashboard_path
    elsif resource.teacher?
      teacher_dashboard_path
    else
      student_dashboard_path
    end
  end

  def after_sign_out_path_for(resource_or_scope)
    homepage_path
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(
      :sign_up,
      keys: [:name, :mobile]
    )

    devise_parameter_sanitizer.permit(
      :account_update,
      keys: [:name, :mobile]
    )
  end

  private

  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: "Access denied."
    end
  end

  def require_teacher
    unless current_user&.teacher? || current_user&.admin?
      redirect_to root_path, alert: "Access denied."
    end
  end

def set_teacher_course
  course_id = params[:course_id] || params[:id]

  return unless course_id.present?

  if current_user.admin?
    @course = Course.find(course_id)
  else
    @course = current_user.teacher.courses.find(course_id)
  end
end
end