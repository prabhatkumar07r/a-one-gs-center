class Admin::PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
 before_action :set_payment, only: [:show, :sync]

  layout "admin"

  PER_PAGE = 20

  # =========================================================
  # INDEX
  # =========================================================

  def index
    # -------------------------------------------------------
    # BASE QUERY
    # -------------------------------------------------------

    payments_scope =
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

    # =======================================================
    # SEARCH
    # =======================================================

    if params[:search].present?
      search_text =
        params[:search].to_s.strip

      unless search_text.blank?
        search =
          "%#{ActiveRecord::Base.sanitize_sql_like(search_text.downcase)}%"

        payments_scope =
          payments_scope
            .joins(
              enrollment: [
                :user,
                :course
              ]
            )
            .where(
              <<~SQL,
                LOWER(users.name) LIKE :search
                OR LOWER(users.email) LIKE :search
                OR LOWER(courses.Course_name) LIKE :search
                OR CAST(payments.id AS TEXT) LIKE :search
                OR LOWER(COALESCE(payments.razorpay_order_id, '')) LIKE :search
                OR LOWER(COALESCE(payments.razorpay_payment_id, '')) LIKE :search
              SQL
              search: search
            )
            .distinct
      end
    end

    # =======================================================
    # STATUS FILTER
    # =======================================================

    selected_status =
      params[:status].to_s.strip.downcase

    allowed_statuses =
      %w[
        paid
        created
        pending
        failed
        cancelled
      ]

    if selected_status.present? &&
       allowed_statuses.include?(selected_status)

      payments_scope =
        payments_scope.where(
          status: selected_status
        )
    end

    # =======================================================
    # COURSE FILTER
    #
    # IMPORTANT:
    # View uses course_id
    # =======================================================

    selected_course_id =
      params[:course_id].to_s.strip

    if selected_course_id.present? &&
       selected_course_id.match?(/\A\d+\z/)

      payments_scope =
        payments_scope
          .joins(enrollment: :course)
          .where(
            enrollments: {
              course_id: selected_course_id.to_i
            }
          )
    end

    # =======================================================
    # FILTERED COUNT
    # =======================================================

    @filtered_payments_count =
      payments_scope.count

    # =======================================================
    # PAGINATION
    # =======================================================

    @page =
      params[:page].to_i

    @page = 1 if @page < 1

    @total_pages =
      (@filtered_payments_count.to_f / PER_PAGE).ceil

    @total_pages = 1 if @total_pages.zero?

    @page =
      @total_pages if @page > @total_pages

    @per_page =
      PER_PAGE

    @payments =
      payments_scope
        .offset(
          (@page - 1) * PER_PAGE
        )
        .limit(PER_PAGE)

    # =======================================================
    # GLOBAL PAYMENT STATISTICS
    #
    # One DB query for all status statistics
    # =======================================================

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
        result[status.to_s] = {
          count: count.to_i,
          sum: sum.to_f
        }
      end

    # -------------------------------------------------------
    # TOTAL PAYMENTS
    # -------------------------------------------------------

    @total_payments =
      stats_by_status.values.sum do |stats|
        stats[:count]
      end

    # -------------------------------------------------------
    # SUCCESSFUL / PAID
    # -------------------------------------------------------

    @successful_payments =
      stats_by_status
        .dig("paid", :count)
        .to_i

    # -------------------------------------------------------
    # PENDING
    #
    # Supports both:
    # created
    # pending
    # -------------------------------------------------------

    @pending_payments =
      stats_by_status
        .values_at("created", "pending")
        .compact
        .sum do |stats|
          stats[:count]
        end

    # -------------------------------------------------------
    # FAILED + CANCELLED
    # -------------------------------------------------------

    @failed_payments =
      stats_by_status
        .values_at("failed", "cancelled")
        .compact
        .sum do |stats|
          stats[:count]
        end

    # -------------------------------------------------------
    # TOTAL REVENUE
    # Only paid payments
    # -------------------------------------------------------

    @total_revenue =
      stats_by_status
        .dig("paid", :sum)
        .to_f

    # =======================================================
    # PAYMENT COURSES
    # =======================================================

    @payment_courses =
      Course
        .where(
          id: Payment
            .joins(:enrollment)
            .select("enrollments.course_id")
        )
        .order(
          Course_name: :asc
        )
        .distinct
  end

  # =========================================================
  # SHOW
  # =========================================================

  def show
  end

def sync
  if @payment.razorpay_order_id.blank?
    redirect_to admin_payment_path(@payment),
                alert: "Razorpay Order ID is missing for this payment."
    return
  end

  if @payment.paid?
    redirect_to admin_payment_path(@payment),
                notice: "Payment is already marked as paid."
    return
  end

  result =
    RazorpayPaymentCompletionService.call(
      payment: @payment,
      razorpay_payment_id: nil,
      razorpay_order_id: @payment.razorpay_order_id
    )

  if result.success
    if result.already_paid
      redirect_to admin_payment_path(@payment),
                  notice: "Payment was already verified."
    else
      redirect_to admin_payment_path(@payment),
                  notice: "Payment synced successfully with Razorpay."
    end
  else
    redirect_to admin_payment_path(@payment),
                alert: result.message
  end
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

    student =
      payment.enrollment.user

    # -------------------------------------------------------
    # EMAIL VALIDATION
    # -------------------------------------------------------

    if student.email.blank?
      redirect_to admin_payment_path(payment),
                  alert: "Student email is missing."
      return
    end

    # -------------------------------------------------------
    # PAYMENT STATUS
    # -------------------------------------------------------

    unless payment.paid?
      redirect_to admin_payment_path(payment),
                  alert: "Payment is not marked as paid."
      return
    end

    # -------------------------------------------------------
    # SEND
    # -------------------------------------------------------

    begin
      BrevoPaymentNotificationService
        .send_success_email(payment)

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

    student =
      payment.enrollment.user

    # -------------------------------------------------------
    # PAID CHECK
    # -------------------------------------------------------

    if payment.paid?
      redirect_to admin_payment_path(payment),
                  alert:
                    "Payment is already marked as paid."
      return
    end

    # -------------------------------------------------------
    # CONTACT AVAILABILITY
    # -------------------------------------------------------

    mobile =
      if student.respond_to?(:mobile)
        student.mobile
      elsif student.respond_to?(:phone)
        student.phone
      end

    has_email =
      student.email.present?

    has_whatsapp =
      mobile.present?

    unless has_email || has_whatsapp
      redirect_to admin_payment_path(payment),
                  alert:
                    "Student email and WhatsApp number are both missing."
      return
    end

    email_sent = false
    whatsapp_sent = false

    errors = []

    # =======================================================
    # EMAIL
    # =======================================================

    if has_email
      begin
        BrevoPaymentNotificationService
          .send_reminder_email(payment)

        email_sent = true

      rescue StandardError => e

        Rails.logger.error(
          "[ADMIN PAYMENT REMINDER EMAIL] " \
          "Payment=#{payment.id} " \
          "#{e.class}: #{e.message}"
        )

        errors << "Email failed: #{e.message}"
      end
    end

    # =======================================================
    # WHATSAPP
    # =======================================================

    if has_whatsapp
      begin
        MetaWhatsappNotificationService
          .send_payment_reminder(payment)

        whatsapp_sent = true

      rescue StandardError => e

        Rails.logger.error(
          "[ADMIN PAYMENT REMINDER WHATSAPP] " \
          "Payment=#{payment.id} " \
          "#{e.class}: #{e.message}"
        )

        errors << "WhatsApp failed: #{e.message}"
      end
    end

    # =======================================================
    # RESULT MESSAGE
    # =======================================================

    sent_channels = []

    sent_channels << "email" if email_sent
    sent_channels << "WhatsApp" if whatsapp_sent

    if sent_channels.any?
      message =
        "Payment reminder sent by #{sent_channels.join(' and ')}."

      if errors.any?
        message += " #{errors.join(' ')}"
      end

      redirect_to admin_payment_path(payment),
                  notice: message
    else
      redirect_to admin_payment_path(payment),
                  alert:
                    errors.join(" ")
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

    channel =
      params[:channel].to_s.strip.downcase

    # -------------------------------------------------------
    # VALIDATE CHANNEL
    # -------------------------------------------------------

    unless %w[email whatsapp both].include?(channel)
      redirect_to admin_payments_path,
                  alert:
                    "Invalid reminder channel."
      return
    end

    # -------------------------------------------------------
    # VALIDATE SELECTION
    # -------------------------------------------------------

    if payment_ids.empty?
      redirect_to admin_payments_path,
                  alert:
                    "Please select at least one unpaid payment."
      return
    end

    # -------------------------------------------------------
    # LOAD PAYMENTS
    # -------------------------------------------------------

    payments =
      Payment
        .includes(
          enrollment: [
            :course,
            :user
          ]
        )
        .where(id: payment_ids)

    # -------------------------------------------------------
    # RESULT COUNTERS
    # -------------------------------------------------------

    results = {
      total: 0,
      email_sent: 0,
      email_failed: 0,
      whatsapp_sent: 0,
      whatsapp_failed: 0,
      skipped: 0
    }

    # =======================================================
    # PROCESS PAYMENTS
    # =======================================================

    payments.each do |payment|

      results[:total] += 1

      # -----------------------------------------------------
      # SKIP PAID
      # -----------------------------------------------------

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

      # =====================================================
      # EMAIL
      # =====================================================

      if %w[email both].include?(channel)

        if student.email.present?

          begin

            BrevoPaymentNotificationService
              .send_reminder_email(payment)

            results[:email_sent] += 1

            Rails.logger.info(
              "[ADMIN BULK PAYMENT REMINDER EMAIL] " \
              "Payment=#{payment.id} " \
              "Student=#{student.id}"
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

      # =====================================================
      # WHATSAPP
      # =====================================================

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

    # =======================================================
    # RESULT MESSAGE
    # =======================================================

    message_parts = []

    if %w[email both].include?(channel)
      message_parts <<
        "#{results[:email_sent]} email(s) sent"
    end

    if %w[whatsapp both].include?(channel)
      message_parts <<
        "#{results[:whatsapp_sent]} WhatsApp message(s) sent"
    end

    if results[:email_failed].positive? &&
       %w[email both].include?(channel)

      message_parts <<
        "#{results[:email_failed]} email(s) failed"
    end

    if results[:whatsapp_failed].positive? &&
       %w[whatsapp both].include?(channel)

      message_parts <<
        "#{results[:whatsapp_failed]} WhatsApp message(s) failed"
    end

    if results[:skipped].positive?
      message_parts <<
        "#{results[:skipped]} skipped"
    end

    # -------------------------------------------------------
    # SAFE FALLBACK
    # -------------------------------------------------------

    if message_parts.empty?
      message_parts <<
        "No reminders were sent."
    end

    # =======================================================
    # REDIRECT
    # =======================================================

    redirect_to admin_payments_path,
                notice:
                  "Bulk reminder completed: " \
                  "#{message_parts.join(', ')}."
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