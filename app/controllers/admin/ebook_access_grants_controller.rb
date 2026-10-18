
class Admin::EbookAccessGrantsController < AdminController
  before_action :set_grant, only: [:revoke]

  def index
    @grants = EbookAccessGrant
      .includes(:user, :ebook, :granted_by)
      .order(created_at: :desc)

    @students = User.student.order(:email)
    @ebooks = Ebook.order(:title)
    @grant = EbookAccessGrant.new
  end

  def create
    user = User.student.find(params[:user_id])
    ebook = Ebook.find(params[:ebook_id])
    reason = params[:reason].to_s.strip

    if reason.blank?
      redirect_to admin_ebook_access_grants_path,
                  alert: "Please enter a reason for granting access."
      return
    end

    grant = EbookAccessGrant.find_or_initialize_by(
      user_id: user.id,
      ebook_id: ebook.id
    )

    if grant.revoked_at.nil? && grant.persisted?
      redirect_to admin_ebook_access_grants_path,
                  alert: "This student already has an active grant."
      return
    end

    grant.granted_by = current_user
    grant.reason = reason
    grant.revoked_at = nil

    if grant.save
      redirect_to admin_ebook_access_grants_path,
                  notice: "E-book access granted to #{user.email}."
    else
      redirect_to admin_ebook_access_grants_path,
                  alert: grant.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_ebook_access_grants_path,
                alert: "Selected student or E-book was not found."
  end

  def revoke
    if @grant.active?
      @grant.revoke!
      redirect_to admin_ebook_access_grants_path,
                  notice: "Manual E-book access revoked."
    else
      redirect_to admin_ebook_access_grants_path,
                  alert: "This grant is already revoked."
    end
  end

  private

  def set_grant
    @grant = EbookAccessGrant.find(params[:id])
  end
end
