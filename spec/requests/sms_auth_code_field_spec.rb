require "spec_helper"

describe "sms auth code field", database_cleaner: :all do

  before(:all) do
    @user = FactoryGirl.create(:user)
    @staffer = FactoryGirl.create(:user, role_name: :staffer)
    @observer = FactoryGirl.create(:user, role_name: :observer)
  end

  context 'in show mode for staffer' do
    before(:all) do
      login(@staffer)
      get("/en/m/#{get_mission.compact_name}/users/#{@user.id}")
      assert_response(:success)
    end

    it 'should be visible' do
      assert_select('div.user_sms_auth_code', true)
    end

    it 'should not have regenerate button' do
      assert_select('div.user_sms_auth_code button', :text => /Regenerate/, :count => 0)
    end
  end

  context 'in edit mode for same user' do
    before(:all) do
      login(@user)
      get("/en/m/#{get_mission.compact_name}/users/#{@user.id}/edit")
    end

    old_key = nil

    it 'should be visible' do
      # Store for later
      assert_select('div.user_sms_auth_code', true) do |e|
        old_key = e.to_s
      end
    end

    it 'should have regenerate button' do
      assert_select('div.user_sms_auth_code button', :text => /Regenerate/, :count => 1)
    end

    context 'on regenerate' do
      it 'should return the new api_key value as json' do
        post(regenerate_api_key_user_path(@user))
        expect(response).to be_success

        @user.reload
        expect(response.body).to eq({ value: @user.api_key }.to_json)
      end

      it 'should have a new key' do
        get "/en/m/#{get_mission.compact_name}/users/#{@user.id}"
        assert_select('div.user_sms_auth_code') do |e|
          expect(old_key).not_to eq e.to_s
        end
      end
    end
  end

  context 'in show mode for observer' do
    before(:all) do
      login(@observer)
      get("/en/m/#{get_mission.compact_name}/users/#{@user.id}")
    end

    it 'should not be visible' do
      assert_select('div.user_sms_auth_code', false)
    end
  end

  context 'in edit mode for observer' do
    before(:all) do
      login(@observer)
      get("/en/m/#{get_mission.compact_name}/users/#{@user.id}/edit")
    end

    it 'should not be visible' do
      assert_select('div.user_sms_auth_code', false)
    end
  end
end
