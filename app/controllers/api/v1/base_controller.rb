module Api
  module V1
    class BaseController < ActionController::API
      RATE_LIMIT  = 100
      RATE_WINDOW = 60 # seconds

      before_action :authenticate_api_key!
      before_action :check_rate_limit

      private

      # ── Authentication ──────────────────────────────────────
      def authenticate_api_key!
        token     = request.headers["Authorization"]&.sub(/\ABearer\s+/, "")
        @api_user = User.find_by(api_key: token) if token.present?

        unless @api_user
          logger.warn { "[API] Unauthorized ip=#{request.remote_ip}" }
          render_error(:unauthorized, "unauthorized", "Missing or invalid API key.")
        end
      end

      # ── Rate limiting ───────────────────────────────────────
      # Counts requests per (user, 60-second window) in the Rails cache.
      # In production the cache backend is Solid Cache; in development/test
      # the memory/null store is used. Rate-limit headers are set on every response.
      def check_rate_limit
        return if performed?

        window    = Time.now.to_i / RATE_WINDOW
        cache_key = "rate_limit:#{@api_user.id}:#{window}"
        count     = Rails.cache.increment(cache_key, 1, expires_in: RATE_WINDOW.seconds).to_i

        reset_at  = (window + 1) * RATE_WINDOW
        remaining = [ RATE_LIMIT - count, 0 ].max

        response.set_header("X-RateLimit-Limit",     RATE_LIMIT.to_s)
        response.set_header("X-RateLimit-Remaining", remaining.to_s)
        response.set_header("X-RateLimit-Reset",     reset_at.to_s)

        if count > RATE_LIMIT
          retry_after = reset_at - Time.now.to_i
          response.set_header("Retry-After", retry_after.to_s)
          logger.warn { "[API] Rate limit exceeded user_id=#{@api_user.id} ip=#{request.remote_ip}" }
          render_error(:too_many_requests, "rate_limit_exceeded",
                       "Rate limit exceeded. Try again in #{retry_after} seconds.")
        end
      end

      # ── Shared error renderer ───────────────────────────────
      def render_error(status, code, message)
        render json: { error: { code: code, message: message } }, status: status
      end
    end
  end
end
