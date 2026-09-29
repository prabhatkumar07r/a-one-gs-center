class Admin::PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_payment, only: [:show, :sync]

  layout "admin"

  PER_PAGE = 20

  def index
    payments_scope = filtered_payments_scope

    @filtered_payments_count = payments_scope.count

    @page = params[:page].to_i
    @page = 1 if @page < 1

    @per_page = PER_PAGE

    @total_pages =
      (
        @filtered_payments_count.to_f /
        @per_page
      ).ceil

    @total_pages = 1 if @total_pages.zero?
    @page = @total_pages if @page > @total_pages

    @payments =
      payments_scope
        .offset((@page - 1) * @per_page)
        .limit(@per_page)

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

    @total_payments =
      stats_by_status.values.sum { |stats| stats[:count] }

    @successful_payments =
      stats_by_status
        .dig("paid", :count)
        .to_i

    @pending_payments =
      stats_by_status
        .values_at("created", "pending")
        .compact
        .sum { |stats| stats[:count] }

    @failed_payments =
      stats_by_status
        .values_at("failed", "cancelled")
        .compact
        .sum { |stats| stats[:count] }

    @total_revenue =
      stats_by_status
        .dig("paid", :sum)
        .to_f

    course_ids =
      Payment
        .joins(:enrollment)
        .distinct
        .pluck("enrollments.course_id")

    @courses =
      Course
        .where(id: course_ids)
        .order(Course_name: :asc)
  end

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

    if student.email.blank?
      redirect_to admin_payment_path(payment),
                  alert: "Student email is missing."
      return
    end

    unless payment.paid?
      redirect_to admin_payment_path(payment),
                  alert: "Payment is not marked as paid."
      return
    end

    begin
      BrevoPaymentNotificationService.send_success_email(payment)

      redirect_to admin_payment_path(payment),
                  notice: "Payment success email sent to #{student.email}."
    rescue StandardError => e
      Rails.logger.error(
        "[ADMIN PAYMENT EMAIL] Payment=#{payment.id} #{e.class}: #{e.message}"
      )

      redirect_to admin_payment_path(payment),
                  alert: "Failed to send payment email: #{e.message}"
    end
  end

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

    if payment.paid?
      redirect_to admin_payment_path(payment),
                  alert: "Payment is already marked as paid."
      return
    end

    mobile = student_contact_number(student)

    has_email = student.email.present?
    has_whatsapp = mobile.present?

    unless has_email || has_whatsapp
      redirect_to admin_payment_path(payment),
                  alert: "Student email and WhatsApp number are both missing."
      return
    end

    email_sent = false
    whatsapp_sent = false
    errors = []

    if has_email
      begin
        BrevoPaymentNotificationService.send_reminder_email(payment)
        email_sent = true
      rescue StandardError => e
        Rails.logger.error(
          "[ADMIN PAYMENT REMINDER EMAIL] Payment=#{payment.id} #{e.class}: #{e.message}"
        )

        errors << "Email failed: #{e.message}"
      end
    end

    if has_whatsapp
      begin
        MetaWhatsappNotificationService.send_payment_reminder(payment)
        whatsapp_sent = true
      rescue StandardError => e
        Rails.logger.error(
          "[ADMIN PAYMENT REMINDER WHATSAPP] Payment=#{payment.id} #{e.class}: #{e.message}"
        )

        errors << "WhatsApp failed: #{e.message}"
      end
    end

    sent_channels = []

    sent_channels << "email" if email_sent
    sent_channels << "WhatsApp" if whatsapp_sent

    if sent_channels.any?
      message =
        "Payment reminder sent by #{sent_channels.join(' and ')}."

      message += " #{errors.join(' ')}" if errors.any?

      redirect_to admin_payment_path(payment),
                  notice: message
    else
      redirect_to admin_payment_path(payment),
                  alert: errors.join(" ")
    end
  end

  def bulk_send_reminders
    payment_ids =
      Array(params[:payment_ids])
        .map(&:to_i)
        .select(&:positive?)
        .uniq

    channel =
      params[:channel].to_s.strip.downcase

    redirect_params = {
      search: params[:search],
      status: params[:status],
      course_id: params[:course_id]
    }

    unless %w[email whatsapp both].include?(channel)
      redirect_to admin_payments_path(redirect_params),
                  alert: "Invalid notification channel."
      return
    end

    if payment_ids.empty?
      redirect_to admin_payments_path(redirect_params),
                  alert: "Please select at least one payment."
      return
    end

    payments_scope = filtered_payments_scope

    allowed_payment_ids =
      payments_scope
        .unscope(:order)
        .where(id: payment_ids)
        .distinct
        .pluck(:id)

    if allowed_payment_ids.empty?
      redirect_to admin_payments_path(redirect_params),
                  alert: "The selected payments are not part of the current filtered results."
      return
    end

    payments =
      Payment
        .includes(
          enrollment: [
            :course,
            :user
          ]
        )
        .where(id: allowed_payment_ids)
        .order(created_at: :desc)

    results = {
      total: 0,
      reminder_email_sent: 0,
      success_email_sent: 0,
      email_failed: 0,
      reminder_whatsapp_sent: 0,
      success_whatsapp_sent: 0,
      whatsapp_failed: 0,
      skipped: 0
    }

    payments.each do |payment|
      results[:total] += 1

      student = payment.enrollment&.user

      unless student
        results[:skipped] += 1
        next
      end

      if payment.paid?
        process_paid_payment_notification(
          payment,
          student,
          channel,
          results
        )
      else
        process_unpaid_payment_notification(
          payment,
          student,
          channel,
          results
        )
      end
    end

    message_parts = []

    if %w[email both].include?(channel)
      email_total =
        results[:reminder_email_sent] +
        results[:success_email_sent]

      message_parts << "Email sent: #{email_total}"
    end

    if %w[whatsapp both].include?(channel)
      whatsapp_total =
        results[:reminder_whatsapp_sent] +
        results[:success_whatsapp_sent]

      message_parts << "WhatsApp sent: #{whatsapp_total}"
    end

    if results[:email_failed] > 0
      message_parts << "Email failed: #{results[:email_failed]}"
    end

    if results[:whatsapp_failed] > 0
      message_parts << "WhatsApp failed: #{results[:whatsapp_failed]}"
    end

    if results[:skipped] > 0
      message_parts << "Skipped: #{results[:skipped]}"
    end

    redirect_to admin_payments_path(redirect_params),
                notice:
                  "Processed #{results[:total]} selected payment(s). #{message_parts.join(' • ')}."
  end

  private

  def process_paid_payment_notification(payment, student, channel, results)
    if %w[email both].include?(channel)
      if student.email.present?
        begin
          BrevoPaymentNotificationService.send_success_email(payment)

          results[:success_email_sent] += 1

          Rails.logger.info(
            "[ADMIN BULK PAYMENT SUCCESS EMAIL] Payment=#{payment.id} Email=#{student.email}"
          )
        rescue StandardError => e
          results[:email_failed] += 1

          Rails.logger.error(
            "[ADMIN BULK PAYMENT SUCCESS EMAIL] Payment=#{payment.id} #{e.class}: #{e.message}"
          )
        end
      else
        results[:email_failed] += 1
      end
    end

    if %w[whatsapp both].include?(channel)
      mobile = student_contact_number(student)

      if mobile.present?
        begin
          MetaWhatsappNotificationService.send_payment_success(payment)

          results[:success_whatsapp_sent] += 1

          Rails.logger.info(
            "[ADMIN BULK PAYMENT SUCCESS WHATSAPP] Payment=#{payment.id} Student=#{student.name}"
          )
        rescue StandardError => e
          results[:whatsapp_failed] += 1

          Rails.logger.error(
            "[ADMIN BULK PAYMENT SUCCESS WHATSAPP] Payment=#{payment.id} #{e.class}: #{e.message}"
          )
        end
      else
        results[:whatsapp_failed] += 1
      end
    end
  end

  def process_unpaid_payment_notification(payment, student, channel, results)
    if %w[email both].include?(channel)
      if student.email.present?
        begin
          BrevoPaymentNotificationService.send_reminder_email(payment)

          results[:reminder_email_sent] += 1

          Rails.logger.info(
            "[ADMIN BULK PAYMENT REMINDER EMAIL] Payment=#{payment.id} Email=#{student.email}"
          )
        rescue StandardError => e
          results[:email_failed] += 1

          Rails.logger.error(
            "[ADMIN BULK PAYMENT REMINDER EMAIL] Payment=#{payment.id} #{e.class}: #{e.message}"
          )
        end
      else
        results[:email_failed] += 1
      end
    end

    if %w[whatsapp both].include?(channel)
      mobile = student_contact_number(student)

      if mobile.present?
        begin
          MetaWhatsappNotificationService.send_payment_reminder(payment)

          results[:reminder_whatsapp_sent] += 1

          Rails.logger.info(
            "[ADMIN BULK PAYMENT REMINDER WHATSAPP] Payment=#{payment.id} Student=#{student.name}"
          )
        rescue StandardError => e
          results[:whatsapp_failed] += 1

          Rails.logger.error(
            "[ADMIN BULK PAYMENT REMINDER WHATSAPP] Payment=#{payment.id} #{e.class}: #{e.message}"
          )
        end
      else
        results[:whatsapp_failed] += 1
      end
    end
  end

  def student_contact_number(student)
    if student.respond_to?(:mobile)
      student.mobile
    elsif student.respond_to?(:phone)
      student.phone
    end
  end

  def filtered_payments_scope
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

  # =========================================================
  # SEARCH FILTER
  # =========================================================

  search_text =
    params[:search].to_s.strip

  if search_text.present?
    search =
      "%#{ActiveRecord::Base.sanitize_sql_like(
        search_text.downcase
      )}%"

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
            OR LOWER(courses."Course_name") LIKE :search
            OR CAST(payments.id AS TEXT) LIKE :search
            OR LOWER(
              COALESCE(payments.razorpay_order_id, '')
            ) LIKE :search
            OR LOWER(
              COALESCE(payments.razorpay_payment_id, '')
            ) LIKE :search
          SQL
          search: search
        )
        .distinct
  end


  # =========================================================
  # STATUS FILTER
  # =========================================================

  selected_status =
    params[:status].to_s.strip.downcase

  allowed_statuses = %w[
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


  # =========================================================
  # COURSE FILTER
  # =========================================================

  selected_course_id =
    params[:course_id].to_s.strip

  if selected_course_id.match?(/\A\d+\z/)
    payments_scope =
      payments_scope
        .joins(enrollment: :course)
        .where(
          enrollments: {
            course_id: selected_course_id.to_i
          }
        )
  end


  # =========================================================
  # FINAL RESULT
  # =========================================================

  payments_scope
end

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

  def require_admin
    redirect_to root_path,
                alert: "Access Denied" unless current_user.admin?
  end
end