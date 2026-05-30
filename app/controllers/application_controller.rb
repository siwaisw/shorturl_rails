class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes
  add_flash_types :short_url

  helper_method :current_user, :logged_in?

  # Log the beginning of every request so request_id, controller, action,
  # and authentication state appear together in one line.
  before_action :log_request_context

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_authentication
    return if logged_in?

    logger.warn { "[Auth] Unauthenticated access attempt action=#{controller_name}##{action_name} ip=#{request.remote_ip}" }
    flash[:alert] = "Please log in to access that page."
    redirect_to login_path
  end

  def log_request_context
    # Block syntax ensures the string is only built when DEBUG is active.
    logger.debug do
      user_ctx = logged_in? ? "user_id=#{current_user.id}" : "user=guest"
      "[Request] #{request.method} #{request.path} controller=#{controller_name}##{action_name} #{user_ctx}"
    end
  end
end
