module Api
  module V1
    class UrlsController < Api::V1::BaseController
      before_action :find_short_url, only: %i[show update destroy]

      # POST /api/v1/urls
      def create
        if params[:url].blank?
          return render_error(:unprocessable_entity, "validation_error", "url is required.")
        end

        limit = @api_user.url_limit
        if limit && @api_user.short_urls.not_deleted.count >= limit
          return render_error(:unprocessable_entity, "quota_exceeded",
                              "You have reached your link limit of #{limit}.")
        end

        short_url = @api_user.short_urls.build(original_url: params[:url])

        if params[:expires_at].present?
          parsed = parse_datetime(params[:expires_at])
          return render_error(:unprocessable_entity, "validation_error",
                              "expires_at must be a valid ISO8601 datetime.") unless parsed
          short_url.expires_at = parsed
        end

        if short_url.save
          logger.info { "[API] Created short_key=#{short_url.short_key} user_id=#{@api_user.id}" }
          render json: serialize(short_url), status: :created
        else
          code = short_url.errors[:original_url].any? ? "invalid_url" : "validation_error"
          render_error(:unprocessable_entity, code, short_url.errors.full_messages.first)
        end
      end

      # GET /api/v1/urls/:key
      def show
        render json: serialize(@short_url)
      end

      # PATCH /api/v1/urls/:key
      def update
        return render_error(:unprocessable_entity, "validation_error",
                            "expires_at is required.") if params[:expires_at].blank?

        parsed = parse_datetime(params[:expires_at])
        return render_error(:unprocessable_entity, "validation_error",
                            "expires_at must be a valid ISO8601 datetime.") unless parsed

        return render_error(:unprocessable_entity, "validation_error",
                            "expires_at must be in the future.") if parsed <= Time.current

        @short_url.update!(expires_at: parsed)
        logger.info { "[API] Updated expiry short_key=#{params[:key]} user_id=#{@api_user.id}" }
        render json: serialize(@short_url)
      end

      # DELETE /api/v1/urls/:key
      def destroy
        @short_url.soft_delete!
        logger.info { "[API] Soft-deleted short_key=#{params[:key]} user_id=#{@api_user.id}" }
        head :no_content
      end

      private

      def find_short_url
        @short_url = @api_user.short_urls.not_deleted.find_by(short_key: params[:key])
        render_error(:not_found, "not_found", "Short URL not found.") unless @short_url
      end

      def serialize(short_url)
        {
          short_key:    short_url.short_key,
          short_url:    "#{request.base_url}/#{short_url.short_key}",
          original_url: short_url.original_url,
          click_count:  short_url.click_count,
          created_at:   short_url.created_at.iso8601,
          expires_at:   short_url.expires_at.iso8601
        }
      end

      def parse_datetime(value)
        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
