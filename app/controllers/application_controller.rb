class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes
  add_flash_types :short_url

  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_authentication
    return if logged_in?

    flash[:alert] = "Please log in to access that page."
    redirect_to login_path
  end
end
