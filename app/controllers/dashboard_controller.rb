class DashboardController < ApplicationController
  before_action :require_authentication

  def index
    @short_urls   = current_user.short_urls.order(created_at: :desc)
    @total_clicks = @short_urls.sum(:click_count)
    @active_count = @short_urls.where("expires_at > ?", Time.current).count

    logger.debug do
      "[Dashboard] Loaded user_id=#{current_user.id} total_links=#{@short_urls.size} active=#{@active_count} total_clicks=#{@total_clicks}"
    end
  end
end
