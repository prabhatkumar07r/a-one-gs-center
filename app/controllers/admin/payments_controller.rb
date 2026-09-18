class Admin::PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :set_payment, only: [:show]

  layout "admin"

  def index
    @payments =
      Payment
        .includes(enrollment: [:user, :course])
        .order(created_at: :desc)
        .limit(50)

    # ==============================
    # PAYMENT STATISTICS
    # ==============================

    @total_payments = Payment.count

    @successful_payments =
      Payment.where(status: "paid").count

    @pending_payments =
      Payment.where(status: "created").count

    @failed_payments =
      Payment.where(
        status: ["failed", "cancelled"]
      ).count

    @total_revenue =
      Payment
        .where(status: "paid")
        .sum(:amount)
  end

  def show
  end

  private

  def set_payment
    @payment =
      Payment
        .includes(enrollment: [:user, :course])
        .find(params[:id])
  end

  def require_admin
    redirect_to root_path, alert: "Access Denied" unless current_user.admin?
  end
end