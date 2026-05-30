require "rails_helper"

RSpec.describe CleanupExpiredUrlsJob, type: :job do
  # ── Fixtures ───────────────────────────────────────────────
  # active_url      — expires in the future, no deleted_at  → untouched
  # expired_url     — expires_at in the past, no deleted_at  → soft-deleted (phase 1)
  #                   then immediately hard-deleted (phase 2 in same run)
  # soft_deleted_url — expires_at in the past, deleted_at set → hard-deleted (phase 2)
  let!(:active_url)       { create(:short_url) }
  let!(:expired_url)      { create(:short_url, :expired) }
  let!(:soft_deleted_url) { create(:short_url, :soft_deleted) }

  describe "#perform" do
    subject(:run_job) { described_class.perform_now }

    # ── Phase 1: soft-delete ─────────────────────────────────
    # Stub phase 2 so records survive long enough to inspect the soft-delete state.
    describe "phase 1 — soft-delete expired URLs" do
      before { allow_any_instance_of(described_class).to receive(:hard_delete_cleanable).and_return(0) }

      it "sets deleted_at on expired URLs that have not been soft-deleted yet" do
        expect { run_job }.to change { expired_url.reload.deleted_at }.from(nil)
      end

      it "does not change deleted_at on URLs that are already soft-deleted" do
        original_ts = soft_deleted_url.deleted_at
        run_job
        expect(soft_deleted_url.reload.deleted_at).to be_within(1.second).of(original_ts)
      end

      it "does not set deleted_at on active URLs" do
        run_job
        expect(active_url.reload.deleted_at).to be_nil
      end
    end

    # ── Phase 2: hard-delete ──────────────────────────────────
    describe "phase 2 — hard-delete soft-deleted expired URLs" do
      it "permanently removes URLs that are expired and soft-deleted" do
        run_job
        expect(ShortUrl.where(id: soft_deleted_url.id)).to be_empty
      end

      it "permanently removes URLs soft-deleted in the same run (phase 1 then phase 2)" do
        run_job
        expect(ShortUrl.where(id: expired_url.id)).to be_empty
      end

      it "does not remove active URLs" do
        run_job
        expect(ShortUrl.exists?(active_url.id)).to be true
      end

      it "removes all expired records in one job run" do
        expect { run_job }.to change(ShortUrl, :count).by(-2)
      end
    end

    # ── Batch size boundary ───────────────────────────────────
    describe "batching" do
      it "processes more records than BATCH_SIZE without error" do
        stub_const("CleanupExpiredUrlsJob::BATCH_SIZE", 2)
        create_list(:short_url, 5, :expired)
        expect { run_job }.not_to raise_error
      end
    end

    # ── Idempotency ───────────────────────────────────────────
    describe "idempotency" do
      it "is safe to run multiple times with no extra side effects" do
        run_job
        count_after_first = ShortUrl.count
        run_job
        expect(ShortUrl.count).to eq(count_after_first)
      end
    end
  end

  # ── Scopes used by the job ────────────────────────────────
  describe "ShortUrl scopes" do
    it ".not_deleted excludes soft-deleted records" do
      expect(ShortUrl.not_deleted).to include(active_url, expired_url)
      expect(ShortUrl.not_deleted).not_to include(soft_deleted_url)
    end

    it ".soft_deleted returns only records with deleted_at set" do
      expect(ShortUrl.soft_deleted).to eq([ soft_deleted_url ])
    end

    it ".expired returns only records with expires_at in the past" do
      expect(ShortUrl.expired).to include(expired_url, soft_deleted_url)
      expect(ShortUrl.expired).not_to include(active_url)
    end

    it ".cleanable returns expired AND soft-deleted records" do
      expect(ShortUrl.cleanable).to eq([ soft_deleted_url ])
    end
  end

  # ── soft_delete! instance method ─────────────────────────
  describe "#soft_delete!" do
    it "sets deleted_at to the current time" do
      expect { active_url.soft_delete! }.to change { active_url.reload.deleted_at }.from(nil)
    end

    it "does not change other attributes" do
      expect { active_url.soft_delete! }.not_to change { active_url.reload.original_url }
    end
  end
end
