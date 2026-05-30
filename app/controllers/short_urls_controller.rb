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
      flash[:short_url] = "#{request.base_url}/#{@short_url.short_key}"
      redirect_to root_path
    else
      flash[:alert] = @short_url.errors.full_messages.first
      redirect_to root_path
    end
  end

  def redirect
    short_url = ShortUrl.find_by(short_key: params[:key])

    return head :not_found unless short_url

    if short_url.expires_at <= Time.current
      redirect_to root_path, alert: "This link has expired."
      return
    end

    short_url.increment!(:click_count)
    redirect_to short_url.original_url, allow_other_host: true, status: :moved_permanently
  end

  private

  def short_url_params
    params.require(:short_url).permit(:original_url)
  end
end
