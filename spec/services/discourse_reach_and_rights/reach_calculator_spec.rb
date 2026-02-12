# frozen_string_literal: true

require "rails_helper"

describe DiscourseReachAndRights::ReachCalculator do
  fab!(:category)
  fab!(:group)
  fab!(:user)

  before do
    category.permissions = { group.name => :readonly }
    category.save!
    group.add(user)
  end

  it "calculates reach correctly" do
    result = DiscourseReachAndRights::ReachCalculator.run
    stat = DiscourseReachAndRights::Stat.find_by(category_id: category.id)

    expect(stat.reach_count).to eq(1)
  end

  describe "mailing list mode" do
    fab!(:ml_user, :user)

    before do
      group.add(ml_user)
      ml_user.user_option.update!(mailing_list_mode: true)
    end

    it "includes mailing list users in watching_count" do
      DiscourseReachAndRights::ReachCalculator.run
      stat = DiscourseReachAndRights::Stat.find_by(category_id: category.id)

      # ml_user is watching because of mailing_list_mode and not muted
      expect(stat.watching_count).to eq(1)
      expect(stat.watching_first_post_count).to eq(0)
    end

    it "excludes mailing list users if they muted the category" do
      CategoryUser.create!(
        user: ml_user,
        category: category,
        notification_level: CategoryUser.notification_levels[:muted],
      )

      DiscourseReachAndRights::ReachCalculator.run
      stat = DiscourseReachAndRights::Stat.find_by(category_id: category.id)

      expect(stat.watching_count).to eq(0)
    end

    it "counts users only once even if they are watching AND in mailing list mode" do
      CategoryUser.create!(
        user: ml_user,
        category: category,
        notification_level: CategoryUser.notification_levels[:watching],
      )

      DiscourseReachAndRights::ReachCalculator.run
      stat = DiscourseReachAndRights::Stat.find_by(category_id: category.id)

      expect(stat.watching_count).to eq(1)
    end
  end

  describe "watching first post" do
    fab!(:first_post_user, :user)

    before do
      group.add(first_post_user)
      CategoryUser.create!(
        user: first_post_user,
        category: category,
        notification_level: CategoryUser.notification_levels[:watching_first_post],
      )
    end

    it "includes watching_first_post correctly" do
      DiscourseReachAndRights::ReachCalculator.run
      stat = DiscourseReachAndRights::Stat.find_by(category_id: category.id)

      expect(stat.watching_count).to eq(0)
      expect(stat.watching_first_post_count).to eq(1)
    end
  end

  describe "public categories" do
    fab!(:public_category) { Fabricate(:category, read_restricted: false) }
    fab!(:another_user, :user)

    it "includes all human active users in reach for public categories" do
      DiscourseReachAndRights::ReachCalculator.run
      stat = DiscourseReachAndRights::Stat.find_by(category_id: public_category.id)

      expect(stat.reach_count).to eq(User.human_users.activated.not_staged.count)
    end
  end

  describe "overlapping groups" do
    fab!(:group_2, :group)
    fab!(:user_2, :user)

    before do
      category.permissions = { group.name => :readonly, group_2.name => :readonly }
      category.save!
      group.add(user_2)
      group_2.add(user_2)
    end

    it "counts users only once even if they are in multiple groups" do
      DiscourseReachAndRights::ReachCalculator.run
      stat = DiscourseReachAndRights::Stat.find_by(category_id: category.id)

      # user and user_2 are the only human users (plus any pre-existing ones in test env, but fab! helps)
      # user is in group
      # user_2 is in group AND group_2
      expect(stat.reach_count).to eq(2)
    end
  end

  describe "system users" do
    it "excludes the system user from reach counts" do
      # Ensure system user is in the group
      group.add(Discourse.system_user)

      DiscourseReachAndRights::ReachCalculator.run
      stat = DiscourseReachAndRights::Stat.find_by(category_id: category.id)

      # Only 'user' should be counted, not system_user
      expect(stat.reach_count).to eq(1)
    end

    it "excludes the system user from public category reach counts" do
      public_category = Fabricate(:category, read_restricted: false)

      DiscourseReachAndRights::ReachCalculator.run
      stat = DiscourseReachAndRights::Stat.find_by(category_id: public_category.id)

      # Should only count human users
      expect(stat.reach_count).to eq(User.human_users.activated.not_staged.count)
    end
  end
end
