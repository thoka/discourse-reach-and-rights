# frozen_string_literal: true
require File.expand_path("../../../../../spec/rails_helper", __dir__)

describe BasicCategorySerializer do
  fab!(:category) { Fabricate(:category) }
  fab!(:user) { Fabricate(:user, trust_level: 1) }
  fab!(:group) { Fabricate(:group) }
  let(:guardian) { Guardian.new(user) }

  before do
    SiteSetting.discourse_reach_and_rights_enabled = true
    SiteSetting.discourse_reach_and_rights_min_trust_level = 1
  end

  it "includes reach_and_rights when enabled" do
    DiscourseReachAndRights::Stat.create!(
      category_id: category.id,
      reach_count: 50,
      watching_count: 10,
      watching_first_post_count: 20,
    )

    serializer = BasicCategorySerializer.new(category, scope: guardian, root: false)
    json = serializer.as_json
    expect(json[:reach_and_rights]).to be_present
    expect(json[:reach_and_rights][:category_id]).to eq(category.id)
    expect(json[:reach_and_rights][:reach_count]).to eq(50)
    expect(json[:reach_and_rights][:watching_count]).to eq(10)
    expect(json[:reach_and_rights][:watching_first_post_count]).to eq(20)
  end

  it "excludes reach_and_rights when trust level is too low" do
    SiteSetting.discourse_reach_and_rights_min_trust_level = 4
    serializer = BasicCategorySerializer.new(category, scope: guardian, root: false)
    json = serializer.as_json
    expect(json[:reach_and_rights]).to be_nil
  end

  it "excludes reach_and_rights when disabled" do
    SiteSetting.discourse_reach_and_rights_enabled = false
    serializer = BasicCategorySerializer.new(category, scope: guardian, root: false)
    json = serializer.as_json
    expect(json[:reach_and_rights]).to be_nil
  end
end
