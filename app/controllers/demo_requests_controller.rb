class DemoRequestsController < ApplicationController

  def new
    @demo = Demo.new
    @courses = Course.order(created_at: :desc)
  end

  def create
    @demo = Demo.new(demo_params)

    if @demo.save
      redirect_to homepage_path,
                  notice: "Demo class request submitted successfully."
    else
      @courses = Course.order(created_at: :desc)

      render :new, status: :unprocessable_entity
    end
  end

  private

  def demo_params
    params.require(:demo).permit(
      :name,
      :phone,
      :email,
      :course,
      :batch,
      :batch_time,
      :preferred_time
    )
  end

end