class ShortUrlsController < ApplicationController
  def create
    @short_url = ShortUrl.new(short_url_params)

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
