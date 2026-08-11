class ApplicationJob < ActiveJob::Base
  # Solid Queue's job table lives in its own physical database (see the
  # `queue:` entry in config/database.yml), on its own connection - so
  # enqueuing from inside an ActiveRecord::Base.transaction (as every
  # ApplicationService organizer does) does NOT defer the insert until that
  # transaction commits. Without this, the queue's worker can pick up and run
  # the job while the enclosing transaction is still open, reading
  # not-yet-committed (or rolled-back) data. This defers enqueuing until the
  # current transaction actually commits.
  self.enqueue_after_transaction_commit = true

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
