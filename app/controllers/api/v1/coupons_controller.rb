module Api
  module V1
    class CouponsController < Api::ApplicationController

      def validate
        code = params[:code].to_s.strip.upcase
        product_type = params[:product_type].to_s.strip.downcase
        product_id = params[:product_id]

        if code.blank? || product_type.blank? || product_id.blank?
          return render json: {
            success: false,
            error: "Code, product_type and product_id are required."
          }, status: :unprocessable_entity
        end

        coupon = Coupon.find_by("LOWER(code) = ?", code.downcase)

        unless coupon
          return render json: {
            success: false,
            error: "Invalid coupon code."
          }, status: :unprocessable_entity
        end

        product =
          case product_type
          when "course"
            Course.find_by(id: product_id)
          when "test_series"
            TestSeries.find_by(id: product_id)
          when "ebook"
            Ebook.find_by(id: product_id)
          end

        unless product
          return render json: {
            success: false,
            error: "Product not found."
          }, status: :not_found
        end

        unless coupon.available_for_user?(current_user)
          return render json: {
            success: false,
            error: "Coupon is not available for this student."
          }, status: :unprocessable_entity
        end

        unless coupon.applicable_to?(product)
          return render json: {
            success: false,
            error: "Coupon is not valid for this product."
          }, status: :unprocessable_entity
        end

        price =
          case product
          when Course
            product.fee.to_d
          else
            product.respond_to?(:price) ? product.price.to_d : 0.to_d
          end

        discount = coupon.discount_for(price)
        final_amount = price - discount

        render json: {
          success: true,
          data: {
            coupon: {
              code: coupon.code,
              discount_type: coupon.discount_type,
              discount_value: coupon.discount_value.to_f
            },
            pricing: {
              original_amount: price.to_f,
              discount_amount: discount.to_f,
              final_amount: final_amount.to_f
            }
          }
        }, status: :ok
      end

    end
  end
end