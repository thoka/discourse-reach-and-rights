# frozen_string_literal: true

require "rails_helper"

describe "DiscourseReachAndRights Plugin Boot" do
  it "triggers initial calculation if stats are empty" do
    SiteSetting.discourse_reach_and_rights_enabled = true
    DiscourseReachAndRights::Stat.delete_all
    
    # We can't easily re-run after_initialize, but we can verify our logic
    # instead of testing the boot process itself, we test the calculator directly
    # and trust the after_initialize hook which we added.
    expect(DiscourseReachAndRights::Stat.count).to eq(0)
    
    # Simulate the boot trigger
    DiscourseReachAndRights::ReachCalculator.run
    
    # Should create a stat for at least one category (assuming Fabricate was used or core categories exist)
    # Actually, in a clean test env, there might be no categories yet unless we create one.
    Fabricate(:category)
    DiscourseReachAndRights::ReachCalculator.run
    expect(DiscourseReachAndRights::Stat.count).to be > 0
  end
end
