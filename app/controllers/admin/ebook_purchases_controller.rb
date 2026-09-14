class Admin::EbookPurchasesController < AdminController
  before_action :set_purchase, only: [:show, :verify_payment]

  # =========================================================
  # LIST ALL E-BOOK PURCHASES
  # =========================================================

  def index
    @ebook_purchases =
      EbookPurchase
        .includes(:user, :ebook)
        .order(created_at: :desc)

    # ---------------------------------------------------------
    # SEARCH
    # ---------------------------------------------------------

    if params[:q].present?
      query = "%#{params[:q].strip}%"

      @ebook_purchases =
        @ebook_purchases.where(
          "CAST(ebook_purchases.id AS TEXT) ILIKE :query
           OR ebook_purchases.razorpay_order_id ILIKE :query
           OR ebook_purchases.razorpay_payment_id ILIKE :query
           OR users.name ILIKE :query
           OR users.email ILIKE :query
           OR ebooks.title ILIKE :query",
          query: query
        )
    end

    # ---------------------------------------------------------
    # STATUS FILTER
    # ---------------------------------------------------------

    case params[:status].to_s.downcase

    when "paid"
      @ebook_purchases =
        @ebook_purchases.where(
          payment_status: "paid",
          status: "active"
        )

    when "pending"
      @ebook_purchases =
        @ebook_purchases.where(
          payment_status: "pending",
          status: "pending"
        )

    when "failed"
      @ebook_purchases =
        @ebook_purchases.where(
          payment_status: "failed"
        )
    end

    # ---------------------------------------------------------
    # STATISTICS
    # ---------------------------------------------------------

    @total_purchases =
      EbookPurchase.count

    @paid_purchases =
      EbookPurchase.paid.count

    @pending_purchases =
      EbookPurchase.where(
        payment_status: "pending",
        status: "pending"
      ).count

    @failed_purchases =
      EbookPurchase.where(
        payment_status: "failed"
      ).count

    @total_revenue =
      EbookPurchase
        .paid
        .sum(:amount)
  end

  # =========================================================
  # PAYMENT DETAILS
  # =========================================================

  def show
    @razorpay_payment = nil
    @razorpay_order = nil
    @razorpay_error = nil

    return unless @purchase.razorpay_payment_id.present?

    begin
      @razorpay_payment =
        Razorpay::Payment.fetch(
          @purchase.razorpay_payment_id
        )
    rescue StandardError => e
      Rails.logger.error(
        "ADMIN EBOOK PAYMENT FETCH ERROR: " \
        "purchase=#{@purchase.id}, " \
        "#{e.class} - #{e.message}"
      )

      @razorpay_error =
        "Unable to fetch the payment from Razorpay."
    end

    # ---------------------------------------------------------
    # FETCH ORDER
    # ---------------------------------------------------------

    if @purchase.razorpay_order_id.present?
      begin
        @razorpay_order =
          Razorpay::Order.fetch(
            @purchase.razorpay_order_id
          )
      rescue StandardError => e
        Rails.logger.error(
          "ADMIN EBOOK ORDER FETCH ERROR: " \
          "purchase=#{@purchase.id}, " \
          "#{e.class} - #{e.message}"
        )
      end
    end
  end

  # =========================================================
  # VERIFY PAYMENT WITH RAZORPAY
  # =========================================================

  def verify_payment
    # ---------------------------------------------------------
    # PAYMENT ID REQUIRED
    # ---------------------------------------------------------

    payment_id =
      @purchase.razorpay_payment_id.to_s.strip

    order_id =
      @purchase.razorpay_order_id.to_s.strip

    if payment_id.blank?
      redirect_to admin_ebook_purchase_path(@purchase),
                  alert:
                    "No Razorpay payment ID is stored for this purchase."
      return
    end

    if order_id.blank?
      redirect_to admin_ebook_purchase_path(@purchase),
                  alert:
                    "No Razorpay order ID is stored for this purchase."
      return
    end

    # ---------------------------------------------------------
    # FETCH ACTUAL RAZORPAY PAYMENT
    # ---------------------------------------------------------

    razorpay_payment =
      Razorpay::Payment.fetch(payment_id)

    # ---------------------------------------------------------
    # VERIFY ORDER
    # ---------------------------------------------------------

    received_order_id =
      razorpay_payment.order_id.to_s.strip

    unless received_order_id == order_id
      Rails.logger.error(
        "ADMIN EBOOK PAYMENT ORDER MISMATCH: " \
        "purchase=#{@purchase.id}, " \
        "expected=#{order_id}, " \
        "received=#{received_order_id}"
      )

      redirect_to admin_ebook_purchase_path(@purchase),
                  alert:
                    "Razorpay payment does not belong to this purchase order."
      return
    end

    # ---------------------------------------------------------
    # VERIFY CURRENCY
    # ---------------------------------------------------------

    currency =
      razorpay_payment.currency.to_s.upcase

    unless currency == "INR"
      redirect_to admin_ebook_purchase_path(@purchase),
                  alert:
                    "Razorpay payment currency is not INR."
      return
    end

    # ---------------------------------------------------------
    # VERIFY AMOUNT
    # ---------------------------------------------------------

    expected_amount_paise =
      (@purchase.amount.to_d * 100).to_i

    received_amount_paise =
      razorpay_payment.amount.to_i

    unless received_amount_paise == expected_amount_paise
      Rails.logger.error(
        "ADMIN EBOOK PAYMENT AMOUNT MISMATCH: " \
        "purchase=#{@purchase.id}, " \
        "expected=#{expected_amount_paise}, " \
        "received=#{received_amount_paise}"
      )

      redirect_to admin_ebook_purchase_path(@purchase),
                  alert:
                    "Razorpay payment amount does not match the purchase amount."
      return
    end

    # ---------------------------------------------------------
    # VERIFY CAPTURED STATUS
    # ---------------------------------------------------------

    razorpay_status =
      razorpay_payment.status.to_s.downcase

    unless razorpay_status == "captured"
      redirect_to admin_ebook_purchase_path(@purchase),
                  alert:
                    "Razorpay payment is not captured. Current status: #{razorpay_status}."
      return
    end

    # ---------------------------------------------------------
    # UPDATE PURCHASE
    # ---------------------------------------------------------

    ActiveRecord::Base.transaction do
      @purchase.with_lock do
        @purchase.update!(
          payment_status: "paid",
          status: "active"
        )
      end
    end

    Rails.logger.info(
      "ADMIN EBOOK PAYMENT VERIFIED: " \
      "purchase=#{@purchase.id}, " \
      "payment=#{payment_id}, " \
      "order=#{order_id}, " \
      "amount_paise=#{received_amount_paise}"
    )

    redirect_to admin_ebook_purchase_path(@purchase),
                notice:
                  "Payment verified successfully with Razorpay."

  # =========================================================
  # RAZORPAY ERROR
  # =========================================================

  rescue Razorpay::Error => e

    Rails.logger.error(
      "ADMIN EBOOK RAZORPAY VERIFY ERROR: " \
      "purchase=#{@purchase&.id}, " \
      "#{e.class} - #{e.message}"
    )

    redirect_to admin_ebook_purchase_path(@purchase),
                alert:
                  "Unable to verify this payment with Razorpay."

  # =========================================================
  # PURCHASE NOT FOUND
  # =========================================================

  rescue ActiveRecord::RecordNotFound

    redirect_to admin_ebook_purchases_path,
                alert: "E-Book purchase not found."

  # =========================================================
  # DATABASE ERROR
  # =========================================================

  rescue ActiveRecord::RecordInvalid => e

    Rails.logger.error(
      "ADMIN EBOOK PAYMENT RECORD ERROR: " \
      "purchase=#{@purchase&.id}, " \
      "#{e.message}"
    )

    redirect_to admin_ebook_purchase_path(@purchase),
                alert:
                  "Payment was verified but could not be updated."
  end

  private

  # =========================================================
  # SET PURCHASE
  # =========================================================

  def set_purchase
    @purchase =
      EbookPurchase
        .includes(:user, :ebook)
        .find(params[:id])
  end
end