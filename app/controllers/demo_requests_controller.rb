class DemoRequestsController < ApplicationController
  def new
    @demo = Demo.new
  end

  def create
    @demo = Demo.new(demo_params)

    if @demo.save
      redirect_to homepage_path, notice: "Demo request submitted successfully!"
    else
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
      :city,
      :preferred_time
    )
  end
end