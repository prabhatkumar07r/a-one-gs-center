class GalleriesController < AdminController

  # ==========================================
  # INDEX
  # ==========================================

  def index

    @galleries =
      Gallery
        .with_attached_photos
        .order(created_at: :desc)


    # ==========================================
    # SEARCH
    # ==========================================

    if params[:search].present?

      search =
        "%#{params[:search]}%"

      @galleries =
        @galleries.where(
          "title ILIKE :search OR description ILIKE :search",
          search: search
        )

    end


    # ==========================================
    # MULTI-CATEGORY FILTER
    # ==========================================

    selected_categories =
      Array(params[:categories])
        .reject(&:blank?)


    if selected_categories.any?

      @galleries =
        @galleries.where(
          "categories && ARRAY[?]::text[]",
          selected_categories
        )

    end


    # ==========================================
    # STATISTICS
    # ==========================================

    @total_gallery =
      Gallery.count

    @active_gallery =
      Gallery.where(status: "Active").count

    @inactive_gallery =
      Gallery.where(status: "Inactive").count

  end


  # ==========================================
  # NEW
  # ==========================================

  def new
    @gallery = Gallery.new
  end


  # ==========================================
  # CREATE
  # ==========================================

  def create

    @gallery =
      Gallery.new(gallery_params)

    if @gallery.save

      redirect_to galleries_path,
                  notice: "Gallery Added Successfully"

    else

      render :new,
             status: :unprocessable_entity

    end

  end


  # ==========================================
  # SHOW
  # ==========================================

  def show

    @gallery =
      Gallery
        .with_attached_photos
        .find(params[:id])

  end


  # ==========================================
  # EDIT
  # ==========================================

  def edit

    @gallery =
      Gallery.find(params[:id])

  end


  # ==========================================
  # UPDATE
  # ==========================================

  def update

    @gallery =
      Gallery.find(params[:id])


    # ------------------------------------------
    # UPDATE TEXT + CATEGORIES
    # ------------------------------------------

    if @gallery.update(
         gallery_params.except(:photos)
       )

      # ----------------------------------------
      # ADD NEW PHOTOS
      # ----------------------------------------

      if gallery_params[:photos].present?

        @gallery.photos.attach(
          gallery_params[:photos]
        )

      end


      redirect_to galleries_path,
                  notice: "Gallery Updated Successfully"

    else

      render :edit,
             status: :unprocessable_entity

    end

  end


  # ==========================================
  # DELETE
  # ==========================================

  def destroy

    @gallery =
      Gallery.find(params[:id])

    @gallery.destroy

    redirect_to galleries_path,
                notice: "Gallery Deleted Successfully"

  end


  private


  # ==========================================
  # STRONG PARAMETERS
  # ==========================================

  def gallery_params

    params
      .require(:gallery)
      .permit(
        :title,
        :description,
        :status,
        categories: [],
        photos: []
      )

  end

end