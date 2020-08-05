# frozen_string_literal: true

# Caches OData that may have changed.
class CacheODataJob < ApplicationJob
  # Batches should be sufficiently small to not interfere with user-initiated jobs like Reports.
  # In practice, 100 responses take ~10-30 seconds to cache on a small VM.
  BATCH_SIZE = 300

  # A user-facing Operation should be created if there are so many responses to cache
  # that it's worth tracking progress.
  OPERATION_THRESHOLD = 1000

  # Frequency at which the Operation.notes should be updated for the user.
  NOTES_INTERVAL = 100

  # Default to lower-priority queue.
  queue_as :odata

  # This can be invoked synchronously or asynchronously, depending on need.
  def self.cache_response(response, logger: Rails.logger)
    json = Results::ResponseJsonGenerator.new(response).as_json
    # Disable validation for a ~25% performance gain.
    response.update_without_validate!(cached_json: json, dirty_json: false)
    json
  rescue StandardError => e
    # Phone home without failing the entire operation.
    logger.debug(debug_msg(e, response))
    ExceptionNotifier.notify_exception(e, data: {shortcode: response.shortcode})
    {error: e.class.name}
  end

  def self.debug_msg(error, response)
    "Failed to update Response #{response.shortcode}\n" \
      "  Mission: #{response.mission.name}\n" \
      "  Form:    #{response.form.name}\n" \
      "  #{error.message}"
  end

  def perform
    # Wait to get called again by the scheduler if this job is already in progress.
    return if existing_jobs > 1

    create_or_update_operation
    cache_batch
    loop_or_finish
  end

  private

  def existing_jobs
    Delayed::Job.where("handler LIKE '%job_class: #{self.class.name}%'").where(failed_at: nil).count
  end

  def existing_operation
    Operation.find_by(job_class: CacheODataOperationJob.name, job_completed_at: nil)
  end

  # Update the existing operation, if found;
  # otherwise create an operation only if the number of responses exceeds the threshold.
  def create_or_update_operation
    if existing_operation.nil?
      return if Response.dirty.count < OPERATION_THRESHOLD
      enqueue_operation
    end
    update_notes
  end

  def cache_batch
    responses = Response.dirty.limit(BATCH_SIZE)
    responses.each_with_index do |response, index|
      CacheODataJob.cache_response(response, logger: Delayed::Worker.logger)
      update_notes if (index % NOTES_INTERVAL).zero?
    end
  end

  def update_notes
    num_responses = Response.dirty.count
    existing_operation.update!(notes: "#{I18n.t('operation.notes.remaining')}: #{num_responses}")
  end

  def enqueue_operation
    operation = Operation.new(
      creator: nil,
      mission: nil,
      job_class: CacheODataOperationJob,
      details: I18n.t("operation.details.cache_odata"),
      job_params: {}
    )
    operation.enqueue
  end

  # Self-enqueue a new batch if there are responses left to cache.
  def loop_or_finish
    if Response.exists?(dirty_json: true)
      self.class.perform_later
    else
      complete_operation
    end
  end

  def complete_operation
    Operation.where(job_class: CacheODataOperationJob.name, job_completed_at: nil)
      .update(job_completed_at: Time.current, notes: nil)
  end
end
