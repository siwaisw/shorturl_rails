class DashboardController < ApplicationController
  before_action :require_authentication

  def index
    @short_urls   = current_user.short_urls.not_deleted.order(created_at: :desc)
    @total_clicks = @short_urls.sum(:click_count)
    @active_count = @short_urls.where("expires_at > ?", Time.current).count

    logger.debug do
      "[Dashboard] Loaded user_id=#{current_user.id} total_links=#{@short_urls.size} active=#{@active_count} total_clicks=#{@total_clicks}"
    end
  end

  def stats
    urls = current_user.short_urls.not_deleted.pluck(:id, :click_count)
    render json: {
      total_clicks: urls.sum { |_, c| c },
      links: urls.map { |id, count| { id: id, click_count: count } }
    }
  end
end
