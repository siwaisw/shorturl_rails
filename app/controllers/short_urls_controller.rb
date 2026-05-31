class ShortUrlsController < ApplicationController
  # 30 mins to 2 years in seconds
  ALLOWED_DURATIONS = [
    1_800, 3_600, 21_600, 43_200,
    86_400, 259_200, 604_800, 1_209_600,
    2_592_000, 7_776_000, 15_552_000, 31_536_000, 63_072_000
  ].freeze

  def create
    @short_url      = ShortUrl.new(short_url_params)
    @short_url.user = current_user if logged_in?

    duration = params.dig(:short_url, :expires_in).to_i
    @short_url.expires_at = (ALLOWED_DURATIONS.include?(duration) ? duration : 1.year.to_i).seconds.from_now

    if @short_url.save
      logger.info do
        user_ctx = logged_in? ? "user_id=#{current_user.id}" : "user=guest"
        "[ShortUrl] Created short_key=#{@short_url.short_key} expires_at=#{@short_url.expires_at.iso8601} #{user_ctx}"
      end

      flash[:short_url] = "#{request.base_url}/#{@short_url.short_key}"
      redirect_to root_path
    else
      logger.warn do
        user_ctx = logged_in? ? "user_id=#{current_user.id}" : "user=guest"
        "[ShortUrl] Failed to create error=#{@short_url.errors.full_messages.first.inspect} #{user_ctx}"
      end

      flash[:alert] = @short_url.errors.full_messages.first
      redirect_to root_path
    end
  end

  def redirect
    # Read from cache (hot path) — falls back to DB on miss and populates the cache.
    cached = ShortUrl.fetch_for_redirect(params[:key])

    unless cached
      logger.warn { "[ShortUrl] Unknown key short_key=#{params[:key].inspect} ip=#{request.remote_ip}" }
      return head :not_found
    end

    if cached[:expires_at] <= Time.current
      logger.warn { "[ShortUrl] Expired link accessed short_key=#{params[:key]} expired_at=#{cached[:expires_at].iso8601} ip=#{request.remote_ip}" }
      redirect_to root_path, alert: "This link has expired."
      return
    end

    # Re-validate the stored URL as HTTP/HTTPS before redirecting (defence-in-depth).
    destination = URI.parse(cached[:original_url])
    unless destination.is_a?(URI::HTTP) && destination.host.present?
      logger.error { "[ShortUrl] Blocked unsafe stored URL short_key=#{params[:key]}" }
      redirect_to root_path, alert: "This link is no longer valid."
      return
    end

    # Increment via direct SQL no need to reload the full record.
    ShortUrl.where(id: cached[:id]).update_all("click_count = click_count + 1")

    logger.info { "[ShortUrl] Redirect short_key=#{params[:key]} destination=#{destination}" }

    redirect_to destination.to_s, allow_other_host: true, status: :moved_permanently
  end

  private

  def short_url_params
    params.require(:short_url).permit(:original_url)
  end
end
