# frozen_string_literal: true

require "rails_helper"

describe Jobs::UpdateReachStats do
  it "calls ReachCalculator and refreshes stats cache when enabled" do
    SiteSetting.discourse_reach_and_rights_enabled = true
    DiscourseReachAndRights::ReachCalculator.expects(:run).once
    DiscourseReachAndRights::StatsStore.expects(:refresh!).once

    Jobs::UpdateReachStats.new.execute({})
  end

  it "does nothing when disabled" do
    SiteSetting.discourse_reach_and_rights_enabled = false
    DiscourseReachAndRights::ReachCalculator.expects(:run).never
    DiscourseReachAndRights::StatsStore.expects(:refresh!).never

    Jobs::UpdateReachStats.new.execute({})
  end
end
