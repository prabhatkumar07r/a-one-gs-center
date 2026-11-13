class Admin::LiveClassesController < AdminController
  layout "admin"

  before_action :set_live_class,
                only: [:show, :edit, :update, :destroy]

  # ==================================================
  # INDEX
  # ==================================================
def index
  @live_classes =
    LiveClass
      .includes(:course)
      .order(scheduled_at: :desc)

  # ==========================================
  # SEARCH
  # ==========================================

  if params[:search].present?
    search_term =
      "%#{ActiveRecord::Base.sanitize_sql_like(params[:search])}%"

    @live_classes =
      @live_classes.where(
        "live_classes.title ILIKE ?",
        search_term
      )
  end

  # ==========================================
  # STATUS FILTER
  # ==========================================

  if params[:status].present?
    @live_classes =
      @live_classes.where(
        status: params[:status]
      )
  end

  # ==========================================
  # ACCESS TYPE FILTER
  # ==========================================

  if params[:access_type].present?
    @live_classes =
      @live_classes.where(
        access_type: params[:access_type]
      )
  end

  # ==========================================
  # STATISTICS
  # ==========================================

  @total_live_classes =
    LiveClass.count

  @upcoming_live_classes =
    LiveClass.where(status: "upcoming").count

  @currently_live_classes =
    LiveClass.where(status: "live").count

  @ended_live_classes =
    LiveClass.where(status: "ended").count
end

  # ==================================================
  # NEW
  # ==================================================

  def new
    @live_class = LiveClass.new
  end

  # ==================================================
  # CREATE
  # ==================================================

  def create
    @live_class = LiveClass.new(live_class_params)

    if @live_class.save
      redirect_to admin_live_classes_path,
                  notice: "Live class created successfully."
    else
      render :new,
             status: :unprocessable_entity
    end
  end

  # ==================================================
  # SHOW
  # ==================================================

  def show
  end

  # ==================================================
  # EDIT
  # ==================================================

  def edit
  end

  # ==================================================
  # UPDATE
  # ==================================================

  def update
    if @live_class.update(live_class_params)
      redirect_to admin_live_classes_path,
                  notice: "Live class updated successfully."
    else
      render :edit,
             status: :unprocessable_entity
    end
  end

  # ==================================================
  # DESTROY
  # ==================================================

  def destroy
    @live_class.destroy!

    redirect_to admin_live_classes_path,
                notice: "Live class deleted successfully."
  end


  # ==================================================
# COURSE PLAYLISTS
# ==================================================

def playlists
  course = Course.find(params[:course_id])

  playlists =
    course.playlists
          .order(:position)
          .select(:id, :title)

  render json: playlists
end

  # ==================================================
  # PRIVATE
  # ==================================================

  private

  def set_live_class
    @live_class = LiveClass.find(params[:id])
  end

  def live_class_params
    params.require(:live_class).permit(
      :course_id,
      :playlist_id,
      :title,
      :description,
      :scheduled_at,
      :duration,
      :access_type,
      :status,
      :provider,
      :stream_url,
      :recording_url
    )
  end
end