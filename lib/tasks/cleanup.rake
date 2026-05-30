namespace :shorturl do
  desc <<~DESC
    Soft-delete expired short URLs then hard-delete them in batches of 1,000.

    Phase 1: sets deleted_at on every record where expires_at < NOW() and deleted_at IS NULL.
    Phase 2: permanently removes every record where expires_at < NOW() and deleted_at IS NOT NULL.

    Safe to run multiple times (idempotent). Intended to be scheduled nightly via cron or
    Solid Queue's recurring-job feature (config/recurring.yml).

    Usage:
      bundle exec rails shorturl:cleanup_expired_urls
  DESC
  task cleanup_expired_urls: :environment do
    CleanupExpiredUrlsJob.perform_now
  end
end
