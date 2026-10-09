
module Api
  module V1
    class BannersController < Api::ApplicationController
      def index
        banners = Banner.active.with_attached_image

        render json: {
          success: true,
          data: {
            banners: banners.map do |banner|
              {
                id: banner.id,
                title: banner.title,
                subtitle: banner.subtitle,
                button_text: banner.button_text,
                button_url: banner.button_url,
                position: banner.position,
                image_url: banner.image.attached? ?
                  rails_blob_url(banner.image, host: request.base_url) : nil
              }
            end
          }
        }, status: :ok
      end
    end
  end
end
