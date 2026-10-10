
module Api
  module V1
    class EbooksController < Api::ApplicationController
      def index
        ebooks = Ebook.where(status: "published")
                      .order(published_at: :desc, created_at: :desc)

        render json: {
          success: true,
          data: {
            ebooks: ebooks.map do |ebook|
              {
                id: ebook.id,
                title: ebook.title,
                description: ebook.description,
                author: ebook.author,
                category: ebook.category,
                language: ebook.language,
                exam_name: ebook.exam_name,
                cover_image_url: cover_image_url_for(ebook),
                price: ebook.price,
                original_price: ebook.original_price,
                discount_percentage: ebook.discount_percentage,
                is_free: ebook.is_free,
                status: ebook.status,
                published_at: ebook.published_at
              }
            end
          }
        }, status: :ok
      end

      def my
        purchases = current_user.ebook_purchases
                                .paid
                                .includes(
                                  ebook: {
                                    cover_image_attachment: :blob,
                                    ebook_files: {
                                      pdf_attachment: :blob
                                    }
                                  }
                                )
                                .order(created_at: :desc)

        render json: {
          success: true,
          data: {
            ebooks: purchases.map do |purchase|
              ebook = purchase.ebook

              {
                purchase_id: purchase.id,
                ebook_id: ebook.id,
                title: ebook.title,
                description: ebook.description,
                author: ebook.author,
                category: ebook.category,
                language: ebook.language,
                exam_name: ebook.exam_name,
                cover_image_url: cover_image_url_for(ebook),
                price: ebook.price,
                original_price: ebook.original_price,
                discount_percentage: ebook.discount_percentage,
                purchased_at: purchase.created_at,
                access_granted: true,
                files: ebook.ebook_files
                             .where(status: "active")
                             .order(:position)
                             .select { |file| file.pdf.attached? }
                             .map do |file|
                  {
                    id: file.id,
                    title: file.title,
                    description: file.description,
                    position: file.position,
                    pdf_available: true
                  }
                end
              }
            end
          }
        }, status: :ok
      end

      def show
        ebook = Ebook.find_by(id: params[:id], status: "published")

        unless ebook
          return render json: {
            success: false,
            error: "E-Book not found."
          }, status: :not_found
        end

        files = ebook.ebook_files.where(status: "active").order(:position)

        render json: {
          success: true,
          data: {
            ebook: {
              id: ebook.id,
              title: ebook.title,
              description: ebook.description,
              author: ebook.author,
              category: ebook.category,
              language: ebook.language,
              exam_name: ebook.exam_name,
              cover_image_url: cover_image_url_for(ebook),
              price: ebook.price,
              original_price: ebook.original_price,
              discount_percentage: ebook.discount_percentage,
              is_free: ebook.is_free,
              status: ebook.status,
              published_at: ebook.published_at
            },
            files: files.map do |file|
              {
                id: file.id,
                title: file.title,
                description: file.description,
                position: file.position,
                status: file.status,
                pdf_available: file.pdf.attached?
              }
            end
          }
        }, status: :ok
      end

      def download_file
        ebook_file = EbookFile.includes(
          :ebook,
          pdf_attachment: :blob
        ).find_by(id: params[:id])

        unless ebook_file
          return render json: {
            success: false,
            error: "E-Book file not found."
          }, status: :not_found
        end

        unless ebook_file.status.to_s == "active"
          return render json: {
            success: false,
            error: "E-Book file is not available."
          }, status: :not_found
        end

        unless ebook_file.pdf.attached?
          return render json: {
            success: false,
            error: "PDF file is not available."
          }, status: :not_found
        end

        ebook = ebook_file.ebook

        unless ebook && ebook.status.to_s == "published"
          return render json: {
            success: false,
            error: "E-Book is not available."
          }, status: :not_found
        end

        unless ebook.free?
          purchase = current_user.ebook_purchases
                                .paid
                                .find_by(ebook_id: ebook.id)

          unless purchase
            return render json: {
              success: false,
              error: "You do not have access to this PDF."
            }, status: :forbidden
          end
        end

        redirect_to rails_blob_path(
          ebook_file.pdf,
          disposition: "inline"
        )
      end

      # Create an E-Book purchase and Razorpay order.
      def purchase
        ebook = Ebook.published.find_by(id: params[:id])

        unless ebook
          return render json: {
            success: false,
            error: "E-Book not found."
          }, status: :not_found
        end

        if ebook.free?
          return render json: {
            success: false,
            error: "This E-Book is free. No purchase is required."
          }, status: :unprocessable_entity
        end

        existing_purchase = current_user.ebook_purchases.find_by(
          ebook_id: ebook.id,
          payment_status: "paid",
          status: "active"
        )

        if existing_purchase
          return render json: {
            success: true,
            message: "E-Book already purchased.",
            data: {
              purchase_id: existing_purchase.id,
              ebook_id: ebook.id,
              payment_status: existing_purchase.payment_status,
              status: existing_purchase.status,
              access_granted: true,
              original_amount: existing_purchase.original_amount.to_d,
              discount_amount: existing_purchase.discount_amount.to_d,
              final_amount: existing_purchase.final_amount.to_d
            }
          }, status: :ok
        end

        # Only the public Key ID is sent to Flutter. Never expose the secret.
        razorpay_key_id = ENV["RAZORPAY_KEY_ID"].to_s.strip

        if razorpay_key_id.blank?
          Rails.logger.error(
            "RAZORPAY_KEY_ID is missing; E-Book checkout cannot start."
          )

          return render json: {
            success: false,
            error: "Payment configuration is unavailable. Please contact support."
          }, status: :internal_server_error
        end

        pending_purchase = current_user.ebook_purchases.where(
          ebook_id: ebook.id,
          payment_status: "pending",
          status: "pending"
        ).where.not(razorpay_order_id: nil).order(id: :desc).first

        if pending_purchase
          pending_purchase.update!(
            payment_status: "cancelled",
            status: "cancelled"
          )
        end

        amount = ebook.price.to_d

        if amount <= 0
          return render json: {
            success: false,
            error: "Invalid E-Book price."
          }, status: :unprocessable_entity
        end

        purchase_record = current_user.ebook_purchases.create!(
          ebook: ebook,
          amount: amount,
          original_amount: amount,
          discount_amount: 0,
          final_amount: amount,
          payment_status: "pending",
          status: "pending"
        )

        coupon_code = params[:coupon_code].to_s.strip.upcase

        if coupon_code.present?
          coupon = Coupon.find_by(
            "LOWER(code) = ?",
            coupon_code.downcase
          )

          unless coupon
            purchase_record.destroy!

            return render json: {
              success: false,
              error: "Invalid coupon code."
            }, status: :unprocessable_entity
          end

          begin
            purchase_record.apply_coupon!(coupon)
          rescue ActiveRecord::RecordInvalid => e
            purchase_record.destroy!

            return render json: {
              success: false,
              error: e.record.errors.full_messages.to_sentence
            }, status: :unprocessable_entity
          end
        end

        final_amount = purchase_record.payable_amount.to_d

        if final_amount <= 0
          purchase_record.destroy!

          return render json: {
            success: false,
            error: "Invalid final payment amount."
          }, status: :unprocessable_entity
        end

        razorpay_amount = (final_amount * 100).round

        if razorpay_amount <= 0
          purchase_record.destroy!

          return render json: {
            success: false,
            error: "Invalid payment amount."
          }, status: :unprocessable_entity
        end

        begin
          razorpay_order = Razorpay::Order.create(
            amount: razorpay_amount,
            currency: "INR",
            receipt: "ebook_api_#{ebook.id}_user_#{current_user.id}_#{Time.current.to_i}"
          )

          purchase_record.update!(
            razorpay_order_id: razorpay_order.id,
            final_amount: final_amount
          )
        rescue Razorpay::Error => e
          Rails.logger.error(
            "E-Book Razorpay order creation failed: #{e.class}"
          )
          purchase_record.destroy!

          return render json: {
            success: false,
            error: "Unable to create payment order. Please try again."
          }, status: :unprocessable_entity
        end

        render json: {
          success: true,
          message: "E-Book purchase created successfully.",
          data: {
            purchase_id: purchase_record.id,
            ebook_id: purchase_record.ebook_id,
            ebook_title: ebook.title,
            amount: final_amount,
            original_amount: purchase_record.original_amount.to_d,
            discount_amount: purchase_record.discount_amount.to_d,
            final_amount: final_amount,
            currency: "INR",
            coupon_code: purchase_record.coupon&.code,
            razorpay_key_id: razorpay_key_id,
            razorpay_order_id: purchase_record.razorpay_order_id,
            payment_status: purchase_record.payment_status,
            status: purchase_record.status,
            access_granted: false
          }
        }, status: :created
      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "E-Book not found."
        }, status: :not_found
      rescue ActiveRecord::RecordInvalid => e
        render json: {
          success: false,
          error: e.record.errors.full_messages.to_sentence
        }, status: :unprocessable_entity
      end

      # Verify the Razorpay payment before granting access.
      def verify_purchase
        purchase_record = current_user.ebook_purchases.find_by(
          id: params[:id]
        )

        unless purchase_record
          return render json: {
            success: false,
            error: "E-Book purchase not found."
          }, status: :not_found
        end

        if purchase_record.paid?
          return render json: {
            success: true,
            message: "Payment already verified.",
            data: {
              purchase_id: purchase_record.id,
              ebook_id: purchase_record.ebook_id,
              payment_status: purchase_record.payment_status,
              status: purchase_record.status,
              access_granted: true
            }
          }, status: :ok
        end

        payment_id = params[:razorpay_payment_id].to_s.strip
        order_id = params[:razorpay_order_id].to_s.strip
        signature = params[:razorpay_signature].to_s.strip

        if payment_id.blank? || order_id.blank? || signature.blank?
          return render json: {
            success: false,
            error: "Payment verification details are incomplete."
          }, status: :unprocessable_entity
        end

        unless order_id == purchase_record.razorpay_order_id.to_s
          return render json: {
            success: false,
            error: "Razorpay order does not match this purchase."
          }, status: :unprocessable_entity
        end

        begin
          Razorpay::Utility.verify_payment_signature(
            razorpay_order_id: order_id,
            razorpay_payment_id: payment_id,
            razorpay_signature: signature
          )
        rescue SecurityError
          return render json: {
            success: false,
            error: "Payment signature verification failed."
          }, status: :unprocessable_entity
        end

        begin
          payment = Razorpay::Payment.fetch(payment_id)
        rescue StandardError => e
          Rails.logger.error(
            "E-Book Razorpay payment fetch failed: #{e.class}"
          )

          return render json: {
            success: false,
            error: "Unable to fetch Razorpay payment."
          }, status: :unprocessable_entity
        end

        unless payment.order_id.to_s == purchase_record.razorpay_order_id.to_s
          return render json: {
            success: false,
            error: "Payment order does not match this purchase."
          }, status: :unprocessable_entity
        end

        unless payment.currency.to_s.upcase == "INR"
          return render json: {
            success: false,
            error: "Invalid payment currency."
          }, status: :unprocessable_entity
        end

        expected_amount = (purchase_record.payable_amount.to_d * 100).round
        actual_amount = payment.amount.to_i

        unless actual_amount == expected_amount
          Rails.logger.warn(
            "E-Book payment amount mismatch for purchase #{purchase_record.id}."
          )

          return render json: {
            success: false,
            error: "Payment amount does not match the purchase amount."
          }, status: :unprocessable_entity
        end

        unless payment.status.to_s == "captured"
          return render json: {
            success: false,
            error: "Payment has not been captured."
          }, status: :unprocessable_entity
        end

        purchase_record.with_lock do
          unless purchase_record.paid?
            purchase_record.update!(
              razorpay_payment_id: payment_id,
              razorpay_signature: signature,
              payment_status: "paid",
              status: "active"
            )
          end
        end

        render json: {
          success: true,
          message: "E-Book payment verified successfully.",
          data: {
            purchase_id: purchase_record.id,
            ebook_id: purchase_record.ebook_id,
            payment_id: payment_id,
            payment_status: purchase_record.payment_status,
            status: purchase_record.status,
            access_granted: true
          }
        }, status: :ok
      rescue ActiveRecord::RecordInvalid
        render json: {
          success: false,
          error: "Unable to update E-Book purchase."
        }, status: :unprocessable_entity
      end

      # Check whether the current user can access an E-Book.
      def access
        ebook = Ebook.find_by(
          id: params[:id],
          status: "published"
        )

        unless ebook
          return render json: {
            success: false,
            error: "E-Book not found."
          }, status: :not_found
        end

        if ebook.is_free?
          return render json: {
            success: true,
            data: {
              ebook_id: ebook.id,
              access_granted: true,
              access_type: "free"
            }
          }, status: :ok
        end

        purchase_record = current_user.ebook_purchases.find_by(
          ebook_id: ebook.id,
          payment_status: "paid",
          status: "active"
        )

        unless purchase_record
          return render json: {
            success: true,
            data: {
              ebook_id: ebook.id,
              access_granted: false,
              access_type: "purchase_required"
            }
          }, status: :ok
        end

        render json: {
          success: true,
          data: {
            ebook_id: ebook.id,
            access_granted: true,
            access_type: "purchased",
            purchase_id: purchase_record.id
          }
        }, status: :ok
      end

      private

      def cover_image_url_for(ebook)
        return nil unless ebook.cover_image.attached?

        "#{request.base_url}#{rails_blob_path(ebook.cover_image, only_path: true)}"
      end
    end
  end
end
