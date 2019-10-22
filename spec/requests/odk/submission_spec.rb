# frozen_string_literal: true

require "rails_helper"

# Using request spec b/c Authlogic won't work with controller spec
#
# NOTE: This spec file is the only one that uses the "odk submissions" context, which is deprecated.
# Future work on this file should switch it to using the newer method of building XML fixtures.
describe "odk submissions", :odk, type: :request do
  include_context "odk submissions"

  let(:mission) { create(:mission) }
  let(:submission_mission) { mission }
  let(:submission_path) { "/m/#{submission_mission.compact_name}/submission" }
  let(:user) { create(:user, role_name: "enumerator", mission: mission) }
  let(:auth_headers) { {"HTTP_AUTHORIZATION" => encode_credentials(user.login, test_password)} }

  before do
    allow_forgery_protection true
  end

  after do
    allow_forgery_protection false
  end

  context "to regular mission" do
    let(:nemo_response) { Response.first }

    describe "get and head requests" do
      it "should return 204 and no content" do
        head(submission_path, params: {format: "xml"}, headers: auth_headers)
        expect(response.response_code).to eq(204)
        expect(response.body).to be_empty

        get(submission_path, params: {format: "xml"}, headers: auth_headers)
        expect(response.response_code).to eq(204)
        expect(response.body).to be_empty
      end
    end

    it "should work and have mission set to current mission" do
      do_submission(submission_path)
      expect(response.response_code).to eq(201)
      expect(nemo_response.answers.map(&:value)).to match_array(%w[5 10])
      expect(nemo_response.mission).to eq(get_mission)
    end

    context "to mission user is not assigned to" do
      let(:submission_mission) { create(:mission) }

      it "should fail" do
        do_submission(submission_path)
        expect(response.response_code).to eq(403)
      end
    end

    it "should fail for non-existent mission" do
      expect { do_submission("/m/foo/submission") }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "should return error 426 upgrade required if old version of form" do
      # Create form build response xml based on it
      f = create(:form, mission: mission, question_types: %w[integer integer])
      f.publish!
      xml = build_odk_submission(f)
      old_version = f.current_version.code

      # Change form and force an upgrade (verify upgrade happened)
      f.unpublish!
      f.c[0].update!(required: true)
      f.reload.publish!
      expect(f.reload.current_version.code).not_to eq(old_version)

      # Try to submit old xml and check for error
      do_submission(submission_path, xml)
      expect(response.response_code).to eq(426)
    end

    it "should return 426 if submitting xml without form version" do
      f = create(:form, mission: mission, question_types: %w[integer integer])
      f.publish!

      # create old xml with no answers (don't need them) but valid form id
      xml = "<?xml version='1.0' ?><data id=\"#{f.id}\"></data>"

      do_submission(submission_path, xml)
      expect(response.response_code).to eq(426)
    end

    it "should fail gracefully on question type mismatch", :investigate do
      # Create form with select one question
      form = create(:form, mission: mission, question_types: %w[select_one])
      form.publish!
      form2 = create(:form, mission: mission, question_types: %w[integer])
      form2.publish!

      # Attempt submission to proper form
      xml = build_odk_submission(form2, data: {form2.questionings[0] => "5"})
      do_submission(submission_path, xml)
      expect(response).to be_successful

      # Answer should look right
      resp = form2.reload.responses.last
      expect(resp.answers.first.value).to eq("5")

      # Attempt submission of value to wrong question
      xml = build_odk_submission(form)
      do_submission(submission_path, xml)
      expect(response).to be_successful

      # Answer should remain blank, integer value should not get stored
      resp = form.reload.responses.last
      expect(resp.answers.first.value).to be_nil
      expect(resp.answers.first.option_id).to be_nil
    end

    it "should be marked incomplete iff there is an incomplete response to a required question" do
      form = create(:form, mission: mission, question_types: %w[integer], allow_incomplete: true)
      form.c[0].update!(required: true)
      form.reload.publish!

      [false, true].each do |no_data|
        resp = do_submission(submission_path, build_odk_submission(form, no_data: no_data))
        expect(response.response_code).to eq(201)
        expect(resp.incomplete).to be(no_data)
      end
    end

    it "should NOT fail if answer is invalid per web validations" do
      form = create(:form, mission: mission, question_types: %w[integer])
      form.c[0].question.update!(minimum: 10)
      form.reload.publish!

      xml = build_odk_submission(form, data: {form.c[0] => "5"})
      do_submission(submission_path, xml)
      expect(response).to be_successful
      expect(Answer.where(questioning_id: form.c[0].id).first.value).to eq("5")
    end
  end

  context "to locked mission" do
    let(:mission) { create(:mission, locked: true) }

    it "should fail" do
      do_submission(submission_path, "foo")
      expect(response.status).to eq(403)
    end
  end

  context "inactive user" do
    let(:user) { create(:user, role_name: "enumerator", active: false) }

    it "should fail" do
      do_submission(submission_path)
      expect(response.response_code).to eq(401)
    end
  end
end
