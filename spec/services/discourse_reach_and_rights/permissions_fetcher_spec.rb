# frozen_string_literal: true
require File.expand_path("../../../../../spec/rails_helper", __dir__)

describe DiscourseReachAndRights::PermissionsFetcher do
  fab!(:category) { Fabricate(:category) }
  # Ensure the group is NOT an automatic group to avoid unexpected members
  fab!(:group) { Fabricate(:group, automatic: false) }
  # Ensure we use fab! correctly for distinct users
  fab!(:user_a, :user) { Fabricate(:user) }
  fab!(:user_b, :user) { Fabricate(:user) }

  before do
    GroupUser.delete_all
    CategoryUser.delete_all
    CategoryGroup.delete_all
    GroupCategoryNotificationDefault.delete_all

    # Ensure category is read_restricted so we use the group-based reach logic
    category.update!(read_restricted: true)

    group.add(user_a)
    group.add(user_b)
    # Wichtig: Der Fetcher basiert auf CategoryGroup
    CategoryGroup.create!(category: category, group: group, permission_type: 1)

    # user_a beobachtet aktiv (Level 3)
    CategoryUser.create!(user: user_a, category: category, notification_level: 3)
    # user_b hat keinen Eintrag -> nutzt Standard (Regular = 1)
  end

  it "calculates correct notification level counts per group and total" do
    result = described_class.call(category: category, guardian: Guardian.new(user_a))

    # 1. Test der Gruppen-Summen
    group_data = result.permissions.find { |g| g[:group_id] == group.id }
    expect(group_data[:notification_levels][3]).to eq(1) # user_a
    expect(group_data[:notification_levels][1]).to eq(1) # user_b (default)

    # 2. Test der Gesamt-Summen
    total_counts = result.category_notification_totals
    expect(total_counts[3]).to eq(1) # user_a
    expect(total_counts[1]).to eq(1) # user_b
  end

  it "does not double-count users in total reach when they are in multiple groups" do
    group_2 = Fabricate(:group, automatic: false)
    group_2.add(user_a)
    CategoryGroup.create!(category: category, group: group_2, permission_type: 1)

    result = described_class.call(category: category, guardian: Guardian.new(user_a))

    # Total reach should be exactly 2 (user_a and user_b), regardless of multiple group memberships
    reach = result.category_notification_totals[:total_reach]
    expect(reach).to eq(2)
  end

  it "uses the highest notification level when multiple levels apply via groups/overrides" do
    group_2 = Fabricate(:group, automatic: false)
    group_2.add(user_a)
    CategoryGroup.create!(category: category, group: group_2, permission_type: 1)

    # Set a group default level for group_2
    GroupCategoryNotificationDefault.create!(
      group: group_2,
      category: category,
      notification_level: NotificationLevels.all[:watching]
    )

    # user_a is already watching via CategoryUser override (3), so it stays 3.
    result = described_class.call(category: category, guardian: Guardian.new(user_a))
    total_counts = result.category_notification_totals
    expect(total_counts[3]).to eq(1) # user_a still 1 in count 3
  end

  it "prioritizes Watching (3) over Watching First Post (4) in totals" do
    # Scenario: User belongs to two groups, one with Watching First Post default,
    # another with Watching default.
    user_prio = Fabricate(:user)
    group_3 = Fabricate(:group, automatic: false)
    group_4 = Fabricate(:group, automatic: false)
    
    group_3.add(user_prio)
    group_4.add(user_prio)
    
    CategoryGroup.create!(category: category, group: group_3, permission_type: 1)
    CategoryGroup.create!(category: category, group: group_4, permission_type: 1)
    
    # Group 3 defaults to Watching (3)
    GroupCategoryNotificationDefault.create!(
      group: group_3,
      category: category,
      notification_level: 3
    )
    # Group 4 defaults to Watching First Post (4)
    GroupCategoryNotificationDefault.create!(
      group: group_4,
      category: category,
      notification_level: 4
    )
    
    result = described_class.call(category: category, guardian: Guardian.new(user_a))
    totals = result.category_notification_totals
    
    # user_prio should be counted in level 3, NOT level 4
    # (user_a is also in level 3 from before block)
    expect(totals[3]).to eq(2) # user_a + user_prio
    expect(totals[4]).to eq(0) 
  end

  it "correctly identifies reach for public categories" do
    # Create a public category
    public_cat = Fabricate(:category, read_restricted: false)
    
    result = described_class.call(category: public_cat, guardian: Guardian.new(user_a))
    reach = result.category_notification_totals[:total_reach]
    
    # In test environment, this counts all active non-staged users with id > 0
    expected_count = User.where("id > 0").where(active: true, staged: false).count
    expect(reach).to eq(expected_count)
    expect(reach).to be >= 2 # At least user_a and user_b
  end
end
