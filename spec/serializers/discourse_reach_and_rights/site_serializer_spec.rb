# frozen_string_literal: true

require "rails_helper"

describe SiteSerializer do
  fab!(:category) { Fabricate(:category) }
  fab!(:user) { Fabricate(:user, trust_level: 1) }
  let(:guardian) { Guardian.new(user) }

  before do
    SiteSetting.discourse_reach_and_rights_enabled = true
    SiteSetting.discourse_reach_and_rights_min_trust_level = 1
    
    DiscourseReachAndRights::Stat.create!(
      category_id: category.id,
      reach_count: 77,
      watching_count: 7,
      watching_first_post_count: 17
    )
  end

  it "includes reach_and_rights in categories" do
    # Re-build site object to ensure cache is fresh or bypassed
    site = Site.new(guardian)
    serializer = SiteSerializer.new(site, scope: guardian, root: false)
    json = serializer.as_json
    
    category_json = json[:categories].find { |c| c[:id] == category.id }
    
    expect(category_json).to be_present
    expect(category_json[:reach_and_rights]).to be_present
    expect(category_json[:reach_and_rights][:reach_count]).to eq(77)
    expect(category_json[:reach_and_rights][:watching_count]).to eq(7)
    expect(category_json[:reach_and_rights][:watching_first_post_count]).to eq(17)
  end
end
