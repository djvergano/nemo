# frozen_string_literal: true

# rubocop:disable Metrics/LineLength
# == Schema Information
#
# Table name: missions
#
#  id           :uuid             not null, primary key
#  compact_name :string(255)      not null
#  locked       :boolean          default(FALSE), not null
#  name         :string(255)      not null
#  shortcode    :string(255)      not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_missions_on_compact_name  (compact_name) UNIQUE
#  index_missions_on_shortcode     (shortcode) UNIQUE
#
# rubocop:enable Metrics/LineLength

def get_mission
  Mission.order(:created_at).first || create(:mission)
end

FactoryGirl.define do
  sequence(:name) { |n| "Mission #{n}" }

  factory :mission do
    transient do
      with_user nil
      role_name :coordinator
    end

    name
    setting { build(:setting) }

    after(:create) do |mission, evaluator|
      mission.assignments.create(user: evaluator.with_user, role: evaluator.role_name.to_s) if evaluator.with_user
    end
  end
end
