class CleanupExpiredUrlsJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 1_000

  # Two-phase cleanup as described in the README:
  #
  #   Phase 1 — soft delete: mark every expired URL with deleted_at so the
  #   record is preserved briefly for audit purposes before permanent removal.
  #
  #   Phase 2 — hard delete: permanently remove all records that are both
  #   expired (expires_at < NOW()) and already soft-deleted (deleted_at IS NOT NULL).
  #
  # Running both phases in the same job keeps operations nightly and simple.
  # To extend the audit-trail window (e.g. keep soft-deleted rows for 7 days),
  # split the phases into separate jobs on different schedules.
  def perform
    soft_deleted_count = soft_delete_expired
    hard_deleted_count = hard_delete_cleanable

    Rails.logger.info do
      "[CleanupExpiredUrlsJob] Done soft_deleted=#{soft_deleted_count} hard_deleted=#{hard_deleted_count}"
    end
  end

  private

  def soft_delete_expired
    count = 0
    ShortUrl.expired.not_deleted.in_batches(of: BATCH_SIZE) do |batch|
      count += batch.update_all(deleted_at: Time.current)
    end
    Rails.logger.info { "[CleanupExpiredUrlsJob] Phase 1 complete soft_deleted=#{count}" }
    count
  end

  def hard_delete_cleanable
    count = 0
    ShortUrl.cleanable.in_batches(of: BATCH_SIZE) do |batch|
      count += batch.delete_all
    end
    Rails.logger.info { "[CleanupExpiredUrlsJob] Phase 2 complete hard_deleted=#{count}" }
    count
  end
end
