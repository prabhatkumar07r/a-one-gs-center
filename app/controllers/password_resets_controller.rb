class PasswordResetsController < ApplicationController
	def new
	end
  def create
  user = User.find_by(email: params[:email])

  if user
    token = SecureRandom.urlsafe_base64

    user.update_columns(reset_password_token: token,
                           reset_password_sent_at:Time.current
                           )

    PasswordResetMailer.reset_email(user).deliver_now

    redirect_to sample_login_path,
                notice: "Password reset link sent to your email."
  else
    flash.now[:alert] = "Email not found."
    render :new
  end
end

def edit
  @user = User.find_by(reset_password_token: params[:id])

  if @user.nil?
    redirect_to new_password_reset_path, alert: "Invalid reset link."
    return
  end

  if @user.reset_password_sent_at < 30.minutes.ago
    redirect_to new_password_reset_path, alert: "Reset link has expired."
    return
  end
end
def update
  @user = User.find_by(reset_password_token: params[:id])

  if @user.nil?
    redirect_to new_password_reset_path, alert: "Invalid or expired reset link."
    return
  end

  if @user.update(
    password: params[:user][:password],
    reset_password_token: nil,
    reset_password_sent_at: nil
  )
    redirect_to sample_login_path, notice: "Password updated successfully."
  else
    puts @user.errors.full_messages
    render :edit, status: :unprocessable_entity
  end
end
end  
