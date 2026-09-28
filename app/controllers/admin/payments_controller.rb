class Admin::PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_payment, only: [:show]

  layout "admin"

  PER_PAGE = 20

  def index
    @payments =
      Payment
        .includes(
          enrollment: [
            {
              user: {
                image_attachment: :blob
              }
            },
            :course
          ]
        )
        .order(created_at: :desc)

    # =========================================================
    # SEARCH
    # =========================================================

    if params[:search].present?
      search = "%#{params[:search].strip.downcase}%"

      @payments =
        @payments
          .joins(
            enrollment: [
              :user,
              :course
            ]
          )
          .where(
            "LOWER(users.name) LIKE :search
             OR LOWER(users.email) LIKE :search
             OR LOWER(courses.Course_name) LIKE :search
             OR CAST(payments.id AS TEXT) LIKE :search
             OR LOWER(payments.razorpay_order_id) LIKE :search
             OR LOWER(payments.razorpay_payment_id) LIKE :search",
            search: search
          )
    end

    # =========================================================
    # STATUS FILTER
    # =========================================================

    if params[:status].present?
      @payments =
        @payments.where(status: params[:status])
    end

    # =========================================================
    # COURSE FILTER
    # =========================================================

    if params[:course].present?
      @payments =
        @payments
          .joins(enrollment: :course)
          .where(
            courses: {
              Course_name: params[:course]
            }
          )
    end

    # =========================================================
    # FILTERED COUNT
    # =========================================================

    @filtered_payments_count =
      @payments.count

    # =========================================================
    # PAGINATION
    # =========================================================

    @page = params[:page].to_i
    @page = 1 if @page < 1

    @total_pages =
      (@filtered_payments_count.to_f / PER_PAGE).ceil

    @total_pages = 1 if @total_pages.zero?

    @page =
      @total_pages if @page > @total_pages

    @per_page = PER_PAGE

    @payments =
      @payments
        .offset((@page - 1) * PER_PAGE)
        .limit(PER_PAGE)

    # =========================================================
    # PAYMENT STATISTICS
    #
    # Previously these were 5 separate queries:
    #   Payment.count
    #   paid.count
    #   created.count
    #   failed/cancelled.count
    #   paid.sum(:amount)
    #
    # Now status statistics are calculated with ONE query.
    # =========================================================

    payment_stats =
  Payment
    .group(:status)
    .pluck(
      :status,
      Arel.sql("COUNT(*)"),
      Arel.sql("COALESCE(SUM(amount), 0)")
    )

stats_by_status =
  payment_stats.each_with_object({}) do |(status, count, sum), result|
    result[status] = {
      count: count.to_i,
      sum: sum.to_f
    }
  end

@total_payments =
  stats_by_status.values.sum { |stats| stats[:count] }

@successful_payments =
  stats_by_status.dig("paid", :count).to_i

@pending_payments =
  stats_by_status.dig("created", :count).to_i

@failed_payments =
  stats_by_status
    .slice("failed", "cancelled")
    .values
    .sum { |stats| stats[:count] }

@total_revenue =
  stats_by_status.dig("paid", :sum).to_f

    # =========================================================
    # PAYMENT COURSES
    # =========================================================

    @payment_courses =
      Course
        .where(
          id: Payment
            .joins(:enrollment)
            .select("enrollments.course_id")
        )
        .order(Course_name: :asc)
  end

  # =========================================================
  # SHOW
  # =========================================================

  def show
  end

  # =========================================================
  # SEND PAYMENT CONFIRMATION EMAIL
  # =========================================================

  def send_email
    payment =
      Payment
        .includes(
          enrollment: [
            {
              user: {
                image_attachment: :blob
              }
            },
            :course
          ]
        )
        .find(params[:id])

    student = payment.enrollment.user

    # ---------------------------------------------------------
    # Email validation
    # ---------------------------------------------------------

    if student.email.blank?
      redirect_to admin_payment_path(payment),
                  alert: "Student email is missing."
      return
    end

    # ---------------------------------------------------------
    # Payment status validation
    # ---------------------------------------------------------

    unless payment.paid?
      redirect_to admin_payment_path(payment),
                  alert: "Payment is not marked as paid."
      return
    end

    begin
      # -------------------------------------------------------
      # Send confirmation email through Brevo
      # -------------------------------------------------------

      BrevoPaymentNotificationService
        .send_success_email(payment)

      # -------------------------------------------------------
      # Save email sent timestamp
      # -------------------------------------------------------

      payment.update!(
        success_email_sent_at: Time.current
      )

      redirect_to admin_payment_path(payment),
                  notice:
                    "Payment success email sent to #{student.email}."

    rescue StandardError => e

      Rails.logger.error(
        "[ADMIN PAYMENT EMAIL] " \
        "#{e.class}: #{e.message}"
      )

      redirect_to admin_payment_path(payment),
                  alert:
                    "Failed to send payment email: #{e.message}"
    end
  end

# =========================================================
# SEND PAYMENT REMINDER
# EMAIL + WHATSAPP
# =========================================================

def send_reminder
  payment =
    Payment
      .includes(
        enrollment: [
          :user,
          :course
        ]
      )
      .find(params[:id])

  student = payment.enrollment.user

  if student.email.blank?
    redirect_to admin_payment_path(payment),
                alert: "Student email is missing."
    return
  end

  if payment.paid?
    redirect_to admin_payment_path(payment),
                alert: "Payment is already marked as paid."
    return
  end

  # ---------------------------------------------------------
  # SEND EMAIL
  # ---------------------------------------------------------

  email_sent = false

  begin
    BrevoPaymentNotificationService
      .send_reminder_email(payment)

    email_sent = true

  rescue StandardError => e

    Rails.logger.error(
      "[ADMIN PAYMENT REMINDER EMAIL] " \
      "#{e.class}: #{e.message}"
    )

    redirect_to admin_payment_path(payment),
                alert:
                  "Payment reminder email failed: #{e.message}"
    return
  end

  # ---------------------------------------------------------
  # SEND WHATSAPP
  # ---------------------------------------------------------

  begin
    MetaWhatsappNotificationService
      .send_payment_reminder(payment)

    whatsapp_sent = true

  rescue StandardError => e

    Rails.logger.error(
      "[ADMIN PAYMENT REMINDER WHATSAPP] " \
      "#{e.class}: #{e.message}"
    )

    # Email was already sent successfully.
    redirect_to admin_payment_path(payment),
                alert:
                  "Payment reminder email sent, " \
                  "but WhatsApp reminder failed: #{e.message}"
    return
  end

  # ---------------------------------------------------------
  # SUCCESS
  # ---------------------------------------------------------

  if email_sent && whatsapp_sent
    redirect_to admin_payment_path(payment),
                notice:
                  "Payment reminder sent successfully by email and WhatsApp to #{student.email}."
  end
end




# =========================================================
# BULK PAYMENT REMINDERS
# EMAIL / WHATSAPP / BOTH
# =========================================================

def bulk_send_reminders
  payment_ids =
    Array(params[:payment_ids])
      .map(&:to_i)
      .select(&:positive?)
      .uniq

  channel = params[:channel].to_s

  # ---------------------------------------------------------
  # VALIDATE CHANNEL
  # ---------------------------------------------------------

  unless %w[email whatsapp both].include?(channel)
    redirect_to admin_payments_path,
                alert: "Invalid reminder channel."
    return
  end

  # ---------------------------------------------------------
  # VALIDATE SELECTION
  # ---------------------------------------------------------

  if payment_ids.empty?
    redirect_to admin_payments_path,
                alert: "Please select at least one unpaid payment."
    return
  end

  # ---------------------------------------------------------
  # LOAD PAYMENTS
  # ---------------------------------------------------------

  payments =
    Payment
      .includes(
        enrollment: [
          :course,
          :user
        ]
      )
      .where(id: payment_ids)

  # ---------------------------------------------------------
  # RESULT COUNTERS
  # ---------------------------------------------------------

  results = {
    total: 0,
    email_sent: 0,
    email_failed: 0,
    whatsapp_sent: 0,
    whatsapp_failed: 0,
    skipped: 0
  }

  # ---------------------------------------------------------
  # PROCESS EACH PAYMENT
  # ---------------------------------------------------------

  payments.each do |payment|

    results[:total] += 1

    # -------------------------------------------------------
    # SKIP ALREADY PAID PAYMENTS
    # -------------------------------------------------------

    if payment.paid?
      results[:skipped] += 1
      next
    end

    student =
      payment.enrollment&.user

    unless student
      results[:skipped] += 1
      next
    end

    # =======================================================
    # EMAIL
    # =======================================================

    if %w[email both].include?(channel)

      if student.email.present?

        begin

          BrevoPaymentNotificationService
            .send_reminder_email(payment)

          results[:email_sent] += 1

          Rails.logger.info(
            "[ADMIN BULK PAYMENT REMINDER EMAIL] " \
            "Payment=#{payment.id} " \
            "Student=#{student.id} " \
            "Email=#{student.email}"
          )

        rescue StandardError => e

          results[:email_failed] += 1

          Rails.logger.error(
            "[ADMIN BULK PAYMENT REMINDER EMAIL] " \
            "Payment=#{payment.id} " \
            "#{e.class}: #{e.message}"
          )

        end

      else

        results[:email_failed] += 1

        Rails.logger.warn(
          "[ADMIN BULK PAYMENT REMINDER EMAIL] " \
          "Payment=#{payment.id} email missing"
        )

      end
    end

    # =======================================================
    # WHATSAPP
    # =======================================================

    if %w[whatsapp both].include?(channel)

      mobile =
        if student.respond_to?(:mobile)
          student.mobile
        elsif student.respond_to?(:phone)
          student.phone
        end

      if mobile.present?

        begin

          MetaWhatsappNotificationService
            .send_payment_reminder(payment)

          results[:whatsapp_sent] += 1

          Rails.logger.info(
            "[ADMIN BULK PAYMENT REMINDER WHATSAPP] " \
            "Payment=#{payment.id} " \
            "Student=#{student.id}"
          )

        rescue StandardError => e

          results[:whatsapp_failed] += 1

          Rails.logger.error(
            "[ADMIN BULK PAYMENT REMINDER WHATSAPP] " \
            "Payment=#{payment.id} " \
            "#{e.class}: #{e.message}"
          )

        end

      else

        results[:whatsapp_failed] += 1

        Rails.logger.warn(
          "[ADMIN BULK PAYMENT REMINDER WHATSAPP] " \
          "Payment=#{payment.id} mobile missing"
        )

      end
    end
  end

  # =========================================================
  # BUILD RESULT MESSAGE
  # =========================================================

  message_parts = []

  if %w[email both].include?(channel)
    message_parts << "#{results[:email_sent]} email(s) sent"
  end

  if %w[whatsapp both].include?(channel)
    message_parts << "#{results[:whatsapp_sent]} WhatsApp message(s) sent"
  end

  if results[:email_failed].positive? &&
     %w[email both].include?(channel)

    message_parts << "#{results[:email_failed]} email(s) failed"
  end

  if results[:whatsapp_failed].positive? &&
     %w[whatsapp both].include?(channel)

    message_parts << "#{results[:whatsapp_failed]} WhatsApp message(s) failed"
  end

  if results[:skipped].positive?
    message_parts << "#{results[:skipped]} skipped"
  end

  # =========================================================
  # REDIRECT
  # =========================================================

  redirect_to admin_payments_path,
              notice:
                "Bulk reminder completed: #{message_parts.join(', ')}."
end
  private

  # =========================================================
  # SET PAYMENT
  # =========================================================

  def set_payment
    @payment =
      Payment
        .includes(
          enrollment: [
            {
              user: {
                image_attachment: :blob
              }
            },
            :course
          ]
        )
        .find(params[:id])
  end

  # =========================================================
  # ADMIN AUTHORIZATION
  # =========================================================

  def require_admin
    redirect_to root_path,
                alert: "Access Denied" unless current_user.admin?
  end
end