module Api
  module V1
    class TestSeriesPurchasesController < Api::ApplicationController

      # =========================================================
      # PURCHASE TEST SERIES
      # POST /api/v1/test_series/:id/purchase
      # =========================================================

      def purchase
        test_series =
          TestSeries
            .active
            .find_by(id: params[:id])

        unless test_series
          return render json: {
            success: false,
            error: "Test Series not found."
          }, status: :not_found
        end

        # -------------------------------------------------------
        # FREE TEST SERIES
        # -------------------------------------------------------

        if test_series.free?
          purchase =
            current_user
              .test_series_purchases
              .find_or_initialize_by(
                test_series: test_series
              )

          purchase.assign_attributes(
            amount: 0,
            original_amount: 0,
            discount_amount: 0,
            final_amount: 0,
            coupon: nil,
            payment_status: "paid",
            status: "Active"
          )

          purchase.save!

          return render json: {
            success: true,
            message: "Test Series access granted.",
            data: {
              purchase_id: purchase.id,
              test_series_id: test_series.id,
              test_series_title: test_series.title,
              original_amount: 0,
              discount_amount: 0,
              final_amount: 0,
              currency: "INR",
              coupon_code: nil,
              payment_status: "paid",
              status: "Active",
              access_granted: true
            }
          }, status: :ok
        end

        # -------------------------------------------------------
        # ALREADY PURCHASED
        # -------------------------------------------------------

        existing_purchase =
          current_user
            .test_series_purchases
            .paid
            .find_by(
              test_series_id: test_series.id
            )

        if existing_purchase
          return render json: {
            success: true,
            message: "Test Series already purchased.",
            data: {
              purchase_id: existing_purchase.id,
              test_series_id: test_series.id,
              test_series_title: test_series.title,
              original_amount:
                existing_purchase.original_price.to_d,
              discount_amount:
                existing_purchase.coupon_discount.to_d,
              final_amount:
                existing_purchase.payable_amount.to_d,
              currency: "INR",
              coupon_code:
                existing_purchase.coupon&.code,
              payment_status:
                existing_purchase.payment_status,
              status:
                existing_purchase.status,
              access_granted: true
            }
          }, status: :ok
        end

        # -------------------------------------------------------
        # CANCEL OLD PENDING PURCHASE
        # -------------------------------------------------------

        pending_purchase =
          current_user
            .test_series_purchases
            .where(
              test_series_id: test_series.id,
              payment_status: "pending",
              status: "Pending"
            )
            .where.not(
              razorpay_order_id: nil
            )
            .order(id: :desc)
            .first

        if pending_purchase
          pending_purchase.update!(
            payment_status: "cancelled",
            status: "cancelled"
          )
        end

        # -------------------------------------------------------
        # BASE PRICE
        # -------------------------------------------------------

        amount =
          test_series.price.to_d

        if amount <= 0
          return render json: {
            success: false,
            error: "Invalid Test Series price."
          }, status: :unprocessable_entity
        end

        # -------------------------------------------------------
        # CREATE PURCHASE
        # -------------------------------------------------------

        purchase =
          current_user
            .test_series_purchases
            .create!(
              test_series: test_series,
              amount: amount,
              original_amount: amount,
              discount_amount: 0,
              final_amount: amount,
              payment_status: "pending",
              status: "Pending"
            )

        # -------------------------------------------------------
        # APPLY COUPON
        # -------------------------------------------------------

        coupon_code =
          params[:coupon_code]
            .to_s
            .strip
            .upcase

        if coupon_code.present?

          coupon =
            Coupon.find_by(
              "LOWER(code) = ?",
              coupon_code.downcase
            )

          unless coupon
            purchase.destroy!

            return render json: {
              success: false,
              error: "Invalid coupon code."
            }, status: :unprocessable_entity
          end

          begin
            purchase.apply_coupon!(
              coupon
            )
          rescue ActiveRecord::RecordInvalid => e
            purchase.destroy!

            return render json: {
              success: false,
              error:
                e.record.errors
                 .full_messages
                 .to_sentence
            }, status: :unprocessable_entity
          end
        end

        # -------------------------------------------------------
        # FINAL AMOUNT
        # -------------------------------------------------------

        final_amount =
          purchase.payable_amount

        if final_amount <= 0
          purchase.destroy!

          return render json: {
            success: false,
            error: "Invalid final payment amount."
          }, status: :unprocessable_entity
        end

        razorpay_amount =
          (final_amount * 100).round

        if razorpay_amount <= 0
          purchase.destroy!

          return render json: {
            success: false,
            error: "Invalid payment amount."
          }, status: :unprocessable_entity
        end

        # -------------------------------------------------------
        # RAZORPAY ORDER
        # -------------------------------------------------------

        begin
          razorpay_order =
            Razorpay::Order.create(
              amount: razorpay_amount,
              currency: "INR",
              receipt:
                "test_series_api_#{test_series.id}_user_#{current_user.id}_#{Time.current.to_i}"
            )

          purchase.update!(
            razorpay_order_id:
              razorpay_order.id
          )

        rescue Razorpay::Error => e
          Rails.logger.error(
            "TEST SERIES API RAZORPAY ERROR: #{e.message}"
          )

          purchase.destroy!

          return render json: {
            success: false,
            error: "Unable to create payment order."
          }, status: :unprocessable_entity
        end

        render json: {
          success: true,
          message:
            "Test Series purchase created successfully.",
          data: {
            purchase_id: purchase.id,
            test_series_id:
              purchase.test_series_id,
            test_series_title:
              test_series.title,

            amount:
              purchase.amount.to_d,

            original_amount:
              purchase.original_amount.to_d,

            discount_amount:
              purchase.discount_amount.to_d,

            final_amount:
              purchase.final_amount.to_d,

            currency: "INR",

            coupon_code:
              purchase.coupon&.code,

            razorpay_order_id:
              purchase.razorpay_order_id,

            payment_status:
              purchase.payment_status,

            status:
              purchase.status,

            access_granted: false
          }
        }, status: :created

      rescue ActiveRecord::RecordNotFound
        render json: {
          success: false,
          error: "Test Series not found."
        }, status: :not_found

      rescue ActiveRecord::RecordInvalid => e
        render json: {
          success: false,
          error:
            e.record.errors
             .full_messages
             .to_sentence
        }, status: :unprocessable_entity
      end


      # =========================================================
      # VERIFY PAYMENT
      # POST /api/v1/test_series/purchases/:id/verify
      # =========================================================

      def verify
        purchase =
          current_user
            .test_series_purchases
            .find_by(id: params[:id])

        unless purchase
          return render json: {
            success: false,
            error: "Test Series purchase not found."
          }, status: :not_found
        end

        if purchase.paid?
          return render json: {
            success: true,
            message: "Payment already verified.",
            data: {
              purchase_id: purchase.id,
              test_series_id:
                purchase.test_series_id,
              payment_status:
                purchase.payment_status,
              status:
                purchase.status,
              access_granted: true
            }
          }, status: :ok
        end

        payment_id =
          params[:razorpay_payment_id]

        order_id =
          params[:razorpay_order_id]

        signature =
          params[:razorpay_signature]

        if payment_id.blank? ||
           order_id.blank? ||
           signature.blank?

          return render json: {
            success: false,
            error:
              "Payment verification details are incomplete."
          }, status: :unprocessable_entity
        end

        unless order_id ==
               purchase.razorpay_order_id

          return render json: {
            success: false,
            error:
              "Razorpay order does not match this purchase."
          }, status: :unprocessable_entity
        end

        # -------------------------------------------------------
        # VERIFY SIGNATURE
        # -------------------------------------------------------

        begin
          Razorpay::Utility.verify_payment_signature(
            {
              razorpay_order_id: order_id,
              razorpay_payment_id: payment_id,
              razorpay_signature: signature
            }
          )
        rescue SecurityError
          return render json: {
            success: false,
            error:
              "Payment signature verification failed."
          }, status: :unprocessable_entity
        end

        # -------------------------------------------------------
        # FETCH PAYMENT
        # -------------------------------------------------------

        begin
          payment =
            Razorpay::Payment.fetch(
              payment_id
            )
        rescue StandardError => e
          Rails.logger.error(
            "TEST SERIES API PAYMENT FETCH ERROR: #{e.message}"
          )

          return render json: {
            success: false,
            error:
              "Unable to fetch Razorpay payment."
          }, status: :unprocessable_entity
        end

        unless payment.order_id.to_s ==
               purchase.razorpay_order_id.to_s

          return render json: {
            success: false,
            error:
              "Payment order does not match this purchase."
          }, status: :unprocessable_entity
        end

        unless payment.currency.to_s.upcase ==
               "INR"

          return render json: {
            success: false,
            error: "Invalid payment currency."
          }, status: :unprocessable_entity
        end

        expected_amount =
          (purchase.payable_amount.to_d * 100).round

        actual_amount =
          payment.amount.to_i

        unless actual_amount ==
               expected_amount

          return render json: {
            success: false,
            error:
              "Payment amount does not match the purchase amount."
          }, status: :unprocessable_entity
        end

        unless payment.status.to_s.downcase ==
               "captured"

          return render json: {
            success: false,
            error:
              "Payment has not been captured."
          }, status: :unprocessable_entity
        end

        # -------------------------------------------------------
        # COMPLETE PURCHASE + COUPON USAGE
        # -------------------------------------------------------

        TestSeriesPurchase.transaction do
          purchase.with_lock do

            purchase.update!(
              amount:
                purchase.payable_amount,

              razorpay_payment_id:
                payment_id,

              razorpay_signature:
                signature,

              payment_status:
                "paid",

              status:
                "Active"
            )

            if purchase.coupon.present?

              CouponUsage.create!(
                coupon:
                  purchase.coupon,

                user:
                  purchase.user,

                purchasable:
                  purchase,

                discount_amount:
                  purchase.discount_amount.to_d,

                used_at:
                  Time.current
              )

              purchase.coupon.increment!(
                :used_count
              )
            end
          end
        end

        render json: {
          success: true,
          message:
            "Test Series payment verified successfully.",
          data: {
            purchase_id:
              purchase.id,

            test_series_id:
              purchase.test_series_id,

            payment_id:
              payment_id,

            original_amount:
              purchase.original_amount.to_d,

            discount_amount:
              purchase.discount_amount.to_d,

            final_amount:
              purchase.final_amount.to_d,

            coupon_code:
              purchase.coupon&.code,

            payment_status:
              purchase.payment_status,

            status:
              purchase.status,

            access_granted: true
          }
        }, status: :ok

      rescue ActiveRecord::RecordInvalid => e
        render json: {
          success: false,
          error:
            e.record.errors
             .full_messages
             .to_sentence
        }, status: :unprocessable_entity

      rescue Razorpay::SignatureVerificationError
        render json: {
          success: false,
          error:
            "Payment signature verification failed."
        }, status: :unprocessable_entity
      end
    end
  end
end