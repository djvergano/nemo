# frozen_string_literal: true

require "rails_helper"

describe Results::ResponseJsonGenerator, :reset_factory_sequences do
  let(:submission_time) { Time.zone.parse("2020-04-20 12:30 UTC") }
  subject(:object) { described_class.new(response).as_json }

  around do |example|
    # Use a weird timezone so we know times are handled properly.
    in_timezone("Saskatchewan") do
      # Need to freeze the time so the times in the expectation file match.
      # The times shown in the resulting JSON should be in the current zone, not UTC.
      # So e.g. 6:30am instead of 12:30pm.
      Timecop.freeze(submission_time) { example.run }
    end
  end

  context "response with various question types" do
    let(:form) do
      create(:form, question_types: ["text",                       # 1
                                     "geo_multilevel_select_one",  # 2
                                     "long_text",                  # 3
                                     "integer",                    # 4
                                     "decimal",                    # 5
                                     "location",                   # 6
                                     "select_one",                 # 7
                                     %w[select_one select_one],    # 8, 9
                                     "select_multiple",            # 10
                                     "datetime",                   # 11
                                     "date",                       # 12
                                     "time",                       # 13
                                     "image"])                     # 14
    end

    context "full multilevel answer" do
      let(:response) do
        create(:response,
          form: form,
          answer_values: ["foo✓", %w[Canada Calgary],
                          "alpha", 100, -123.50,
                          "15.937378 44.36453", "Cat", %w[Dog Cat], %w[Dog Cat],
                          "2015-10-12 18:15:12 UTC", "2014-11-09", "23:15"])
      end

      it "produces correct json" do
        is_expected.to match_json(prepare_response_json_expectation("basic.json"))
      end
    end
  end

  def prepare_response_json_expectation(filename)
    prepare_fixture("response_json/#{filename}",
      id: [response.id], shortcode: [response.shortcode])
  end
end
