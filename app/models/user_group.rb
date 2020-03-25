# frozen_string_literal: true

# rubocop:disable Metrics/LineLength
# == Schema Information
#
# Table name: user_groups
#
#  id         :uuid             not null, primary key
#  name       :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  mission_id :uuid             not null
#
# Indexes
#
#  index_user_groups_on_mission_id           (mission_id)
#  index_user_groups_on_name_and_mission_id  (name,mission_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (mission_id => missions.id)
#
# rubocop:enable Metrics/LineLength

class UserGroup < ApplicationRecord
  include MissionBased

  has_many :user_group_assignments, dependent: :destroy
  has_many :users, through: :user_group_assignments
  has_many :broadcast_addressings, inverse_of: :addressee, foreign_key: :addressee_id, dependent: :destroy
  has_many :form_forwardings, inverse_of: :recipient, foreign_key: :recipient_id, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: {scope: :mission_id}

  scope :by_name, -> { order(:name) }
  scope :name_matching, ->(q) { where("name ILIKE ?", "%#{q}%") }

  # remove heirarchy of objects
  def self.terminate_sub_relationships(group_ids)
    UserGroupAssignment.where(user_group_id: group_ids).delete_all
  end
end
