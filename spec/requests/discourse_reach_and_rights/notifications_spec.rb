# frozen_string_literal: true

require File.expand_path("../../../../../spec/rails_helper", __dir__)

RSpec.describe DiscourseReachAndRights::PermissionsController do
  before { enable_current_plugin }

  fab!(:group)
  fab!(:category)
  fab!(:user)
  fab!(:user_in_group, :user)

  before do
    SiteSetting.discourse_reach_and_rights_enabled = true
    user.update!(admin: true)
    group.add(user_in_group)
    sign_in(user)
  end

  describe "notifications" do
    it "returns the default notification level for a group" do
      GroupCategoryNotificationDefault.create!(
        group: group,
        category: category,
        notification_level: NotificationLevels.all[:watching],
      )

      get "/c/#{category.id}/reach-and-rights", xhr: true

      expect(response.status).to eq(200)
      json = response.parsed_body

      group_perm = json["group_permissions"].find { |p| p["group_id"] == group.id }
      expect(group_perm).to be_present
      expect(group_perm["notification_level"]).to eq(NotificationLevels.all[:watching])
    end

    it "includes a group that only has notification defaults but no specific category permissions" do
      # Set no specific category permissions for the group
      category.set_permissions(admins: :full) # only admins
      category.save!

      # Set a notification default for the group
      GroupCategoryNotificationDefault.create!(
        group: group,
        category: category,
        notification_level: NotificationLevels.all[:watching],
      )

      get "/c/#{category.id}/reach-and-rights", xhr: true

      expect(response.status).to eq(200)
      json = response.parsed_body

      group_ids = json["group_permissions"].map { |p| p["group_id"] }
      expect(group_ids).to include(group.id)
    end

    it "returns the correct notified_count for a group" do
      # Case: Group is watching, so all members are notified
      GroupCategoryNotificationDefault.create!(
        group: group,
        category: category,
        notification_level: NotificationLevels.all[:watching],
      )

      # Add another user to group
      another_user = Fabricate(:user)
      group.add(another_user)

      get "/c/#{category.id}/reach-and-rights", xhr: true

      json = response.parsed_body
      group_perm = json["group_permissions"].find { |p| p["group_id"] == group.id }

      # user_in_group and another_user are in the group.
      expect(group_perm["notification_levels"]["3"]).to eq(2) # Level 3 = Watching
    end

    it "adjusts notification levels based on individual user overrides" do
      GroupCategoryNotificationDefault.create!(
        group: group,
        category: category,
        notification_level: NotificationLevels.all[:watching],
      )

      # user_in_group mutes the category manually
      CategoryUser.create!(
        user: user_in_group,
        category: category,
        notification_level: NotificationLevels.all[:muted],
      )

      get "/c/#{category.id}/reach-and-rights", xhr: true

      json = response.parsed_body
      group_perm = json["group_permissions"].find { |p| p["group_id"] == group.id }

      # Group Watching(3) but User Muted(0)
      expect(group_perm["notification_levels"]["3"].to_i).to eq(0)
      expect(group_perm["notification_levels"]["0"].to_i).to eq(1)
    end

    it "returns aggregate notification counts for the entire category including group defaults" do
      # user_in_group is in 'group', which gets a default
      GroupCategoryNotificationDefault.create!(
        group: group,
        category: category,
        notification_level: NotificationLevels.all[:watching],
      )

      # Another user is not in any specific group but has an override to Tracking
      another_user = Fabricate(:user)
      CategoryUser.create!(
        user: another_user,
        category: category,
        notification_level: NotificationLevels.all[:tracking],
      )

      get "/c/#{category.id}/reach-and-rights", xhr: true

      json = response.parsed_body
      totals = json["category_notification_totals"]

      # level 3 = watching (user_in_group via group default)
      # level 2 = tracking (another_user via explicit override)
      expect(totals["3"]).to eq(1)
      expect(totals["2"]).to eq(1)
    end
  end
end
