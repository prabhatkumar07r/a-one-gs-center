class EventsController < ApplicationController
  before_action :authenticate_user!
  before_action :check_admin
  before_action :set_event, only: [:show, :edit, :update, :destroy]

  def index
    @events = Event.order(created_at: :desc)
  end

  def show
  end

  def new
    @event = Event.new
  end

  def create
    @event = Event.new(event_params)

    if @event.save
      redirect_to events_path, notice: "Event created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @event.update(event_params)
      redirect_to events_path, notice: "Event updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to events_path, notice: "Event deleted successfully."
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(:title, :status, :photo)
  end

  def check_admin
    unless current_user&.admin?
      redirect_to homepage_path, alert: "Access Denied!"
    end
  end
end