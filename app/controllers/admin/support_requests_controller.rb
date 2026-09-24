module Admin
  class SupportRequestsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin
    before_action :set_support_request, only: [:show, :update]

    layout "admin"

    def index
      @status   = params[:status].to_s
      @category = params[:category].to_s
      @search   = params[:search].to_s.strip

      # =====================================================
      # STATS
      # =====================================================

      @open_count =
        Ai::SupportRequest
          .where(status: %w[open in_progress])
          .count

      @urgent_count =
        Ai::SupportRequest
          .where(priority: "urgent")
          .where.not(status: %w[resolved closed])
          .count

      @total_count =
        Ai::SupportRequest.count

      @resolved_count =
        Ai::SupportRequest
          .where(status: %w[resolved closed])
          .count

      # =====================================================
      # REQUEST LIST
      # =====================================================

      @support_requests =
        Ai::SupportRequest
          .includes(:user, :admin_user)
          .recent

      if @status.present?
        @support_requests =
          @support_requests.where(status: @status)
      end

      if @category.present?
        @support_requests =
          @support_requests.where(category: @category)
      end

      if @search.present?
        search_term = "%#{@search}%"

        @support_requests =
          @support_requests
            .left_joins(:user)
            .where(
              "ai_support_requests.id::text ILIKE :search
               OR ai_support_requests.subject ILIKE :search
               OR ai_support_requests.description ILIKE :search
               OR users.name ILIKE :search
               OR users.email ILIKE :search",
              search: search_term
            )
            .distinct
      end

      @support_requests =
        @support_requests
          .page(params[:page])
          .per(20)

      # =====================================================
      # SELECTED REQUEST FOR RIGHT PANEL
      # =====================================================

      selected_id =
        params[:selected_id].presence ||
        params[:id].presence

      if selected_id.present?
        @selected_request =
          Ai::SupportRequest
            .includes(
              :user,
              :admin_user,
              :ai_conversation,
              messages: :user
            )
            .find_by(id: selected_id)
      end

      @selected_request ||= @support_requests.first

      if @selected_request
        @support_messages =
          @selected_request
            .messages
            .includes(:user)
            .chronological
      else
        @support_messages = []
      end
    end

    def show
      @support_messages =
        @support_request
          .messages
          .includes(:user)
          .chronological
    end

    def update
      previous_status = @support_request.status

      @support_request.assign_attributes(
        category: support_request_params[:category],
        priority: support_request_params[:priority],
        status: support_request_params[:status],
        subject: support_request_params[:subject],
        description: support_request_params[:description]
      )

      if @support_request.status == "resolved" ||
         @support_request.status == "closed"

        @support_request.resolved_at ||= Time.current
      else
        @support_request.resolved_at = nil
      end

      if @support_request.status == "in_progress" &&
         previous_status != "in_progress"

        @support_request.admin_user_id ||= current_user.id
      end

      @support_request.save!

      redirect_to admin_support_requests_path(
        selected_id: @support_request.id
      ),
                  notice: "Support request updated successfully."
    rescue ActionController::ParameterMissing => e
      redirect_to admin_support_requests_path(
        selected_id: @support_request.id
      ),
                  alert: e.message
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_support_requests_path(
        selected_id: @support_request.id
      ),
                  alert: e.record.errors.full_messages.to_sentence
    end

    private

    def require_admin
      redirect_to root_path,
                  alert: "Access Denied" unless current_user.admin?
    end

    def set_support_request
      @support_request =
        Ai::SupportRequest
          .includes(
            :user,
            :admin_user,
            :ai_conversation,
            messages: :user
          )
          .find(params[:id])
    end

    def support_request_params
      params.require(:ai_support_request).permit(
        :category,
        :priority,
        :status,
        :subject,
        :description
      )
    end
  end
end