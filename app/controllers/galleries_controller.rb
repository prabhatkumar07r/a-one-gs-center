class GalleriesController < ApplicationController

  def index
    @galleries = Gallery.order(created_at: :desc)

    if params[:search].present?
      @galleries = @galleries.where(
        "title LIKE ? OR category LIKE ?",
        "%#{params[:search]}%",
        "%#{params[:search]}%"
      )
    end

    @total_gallery = Gallery.count
    @active_gallery = Gallery.where(status: "Active").count
    @inactive_gallery = Gallery.where(status: "Inactive").count
  end

  def new
    @gallery = Gallery.new
  end

  def create
    @gallery = Gallery.new(gallery_params)

    if @gallery.save
      redirect_to galleries_path, notice: "Gallery Added Successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @gallery = Gallery.find(params[:id])
  end

  def edit
    @gallery = Gallery.find(params[:id])
  end

 def update
  @gallery = Gallery.find(params[:id])

  # Sirf text fields update karo
  if @gallery.update(gallery_params.except(:photos))

    # Naye photos ko existing photos ke saath attach karo
    if gallery_params[:photos].present?
      @gallery.photos.attach(gallery_params[:photos])
    end

    redirect_to galleries_path, notice: "Gallery Updated Successfully"
  else
    render :edit, status: :unprocessable_entity
  end
end

  def destroy
    @gallery = Gallery.find(params[:id])
    @gallery.destroy

    redirect_to galleries_path, notice: "Gallery Deleted Successfully"
  end

  private

  def gallery_params
    params.require(:gallery).permit(
      :title,
      :category,
      :description,
      :status,
      photos: []
    )
  end

end