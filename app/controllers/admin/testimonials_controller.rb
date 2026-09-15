class Admin::TestimonialsController < ApplicationController

  layout "admin"

  before_action :authenticate_user!
  before_action :require_admin!

  before_action :set_testimonial,
                only: %i[
                  edit
                  update
                  destroy
                  toggle_status
                ]

  def index
    @testimonials =
      Testimonial
        .order(:display_order, created_at: :desc)
  end

  def new
    @testimonial =
      Testimonial.new(
        rating: 5,
        status: "Active",
        display_order: 0
      )
  end

  def create
    @testimonial =
      Testimonial.new(testimonial_params)

    if @testimonial.save
      redirect_to admin_testimonials_path,
                  notice: "Testimonial created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @testimonial.update(testimonial_params)
      redirect_to admin_testimonials_path,
                  notice: "Testimonial updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @testimonial.destroy

    redirect_to admin_testimonials_path,
                notice: "Testimonial deleted successfully."
  end

  def toggle_status
    new_status =
      @testimonial.status == "Active" ? "Inactive" : "Active"

    @testimonial.update!(status: new_status)

    redirect_to admin_testimonials_path,
                notice: "Testimonial status updated."
  end

  private

  def set_testimonial
    @testimonial = Testimonial.find(params[:id])
  end

  def testimonial_params
    params.require(:testimonial).permit(
      :student_name,
      :message,
      :rating,
      :status,
      :display_order,
      :student_photo,
      :video
    )
  end

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path,
                  alert: "You are not authorized to access this page."
    end
  end

end