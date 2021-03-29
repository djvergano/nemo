# frozen_string_literal: true

# rubocop:disable Layout/LineLength
# == Schema Information
#
# Table name: media_objects
#
#  id                :uuid             not null, primary key
#  item_content_type :string(255)      not null
#  item_file_name    :string(255)      not null
#  item_file_size    :integer          not null
#  item_updated_at   :datetime         not null
#  type              :string(255)      not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  answer_id         :uuid
#
# Indexes
#
#  index_media_objects_on_answer_id  (answer_id)
#
# Foreign Keys
#
#  media_objects_answer_id_fkey  (answer_id => answers.id) ON DELETE => restrict ON UPDATE => restrict
#
# rubocop:enable Layout/LineLength

module Media
  # Abstract class for Answer attachments.
  # Need to use ::Media prefix or things break :(
  class ::Media::Object < ApplicationRecord
    belongs_to :answer

    # A note on validation for subclasses:
    # We no longer validate file extensions because we can't anticipate what extensions folks
    # will be sending from ODK Collect (since the platform changes over time)
    # and there is no easy way to allow the user to correct behavior on validation fail-we just have to
    # discard the file. So for that we reason we limit to mime type validation only since that still
    # provides some security but is less restrictive and less superficial.
    has_one_attached :item
    validates :item, attached: true

    delegate :mission, to: :answer
    delegate :response, to: :answer, allow_nil: true

    scope :expired, -> { where(answer_id: nil).where("created_at < ?", 12.hours.ago) }

    after_save :generate_media_object_filename

    def dynamic_thumb?
      false
    end

    # Set a useful filename to assist data analysts who deal with lots of downloads.
    def generate_media_object_filename
      return if item.record.answer_id.nil?

      repeat_groups = []
      answer = item.record.answer
      extension = File.extname(item.filename.to_s)
      filename = "nemo-#{answer.response.shortcode}"

      # build a more complex filename if is nested in repeat groups
      if answer.parent_group_name.present?
        answer_group = next_agroup_up(answer.parent_id)
        repeat_groups = respect_ancestors(answer_group, repeat_groups) if answer_group.repeatable?
      end

      filename += "-#{repeat_groups.pop}" until repeat_groups.empty?
      filename += extension
      item.blob.update!(filename: filename)
    end

    def respect_ancestors(answer_group, repeat_groups)
      repeat_groups << "#{answer_group.group_name.gsub(/\s+/, '_')}#{answer_group.new_rank + 1}"
      if answer_group.parent_id.present?
        parent_answer_group = next_agroup_up(answer_group.parent_id)
        if parent_answer_group.present? && parent_answer_group.group_name.present?
          repeat_groups = respect_ancestors(parent_answer_group, repeat_groups)
        end
      end
      repeat_groups
    end

    def next_agroup_up(agroup_id)
      parent = ResponseNode.find(agroup_id)
      if parent.type != "AnswerGroup" && parent.parent_id.present?
        next_agroup_up(parent.parent_id)
      else
        parent
      end
    end
  end
end
