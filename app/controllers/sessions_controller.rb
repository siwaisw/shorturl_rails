class SessionsController < ApplicationController
  def new
    redirect_to dashboard_path if logged_in?
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)

    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      logger.info { "[Session] Login user_id=#{user.id} ip=#{request.remote_ip}" }
      redirect_to dashboard_path, notice: "Welcome back!"
    else
      # Log at warn — a failed login may indicate a brute-force attempt.
      logger.warn { "[Session] Failed login ip=#{request.remote_ip} user_found=#{user.present?}" }
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    logger.info { "[Session] Logout user_id=#{session[:user_id]} ip=#{request.remote_ip}" }
    session.delete(:user_id)
    redirect_to root_path, notice: "You've been logged out."
  end
end
