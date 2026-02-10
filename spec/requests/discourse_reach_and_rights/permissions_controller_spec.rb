# frozen_string_literal: true

require File.expand_path("../../../../../spec/rails_helper", __dir__)

RSpec.describe DiscourseReachAndRights::PermissionsController do
  before { enable_current_plugin }

  fab!(:group)
  fab!(:category)
  fab!(:private_category) { Fabricate(:private_category, group: group) }
  fab!(:user)

  before do
    SiteSetting.discourse_reach_and_rights_enabled = true
    category.set_permissions(group.name => :create_post)
    category.save!
  end

  it "requires login" do
    get "/c/#{category.id}/reach-and-rights", xhr: true
    expect(response.status).to eq(403)
  end

  it "returns group permissions for a visible category" do
    sign_in(user)
    group.add(user)

    get "/c/#{category.id}/reach-and-rights", xhr: true

    expect(response.status).to eq(200)
    json = response.parsed_body

    expect(json["category_id"]).to eq(category.id)
    expect(json["category_name"]).to eq(category.name)
    expect(json["group_permissions"]).to contain_exactly(
      hash_including(
        "permission_type" => CategoryGroup.permission_types[:create_post],
        "permission" => "create_post",
        "group_name" => group.name,
        "group_id" => group.id,
      ),
    )
  end

  it "returns 'everyone' permissions for a public category" do
    sign_in(user)
    category.set_permissions(admins: :full) # Restricted to admins
    category.save!
    category.update!(read_restricted: false) # But publicly visible

    get "/c/#{category.id}/reach-and-rights", xhr: true

    expect(response.status).to eq(200)
    json = response.parsed_body

    everyone_group = Group[:everyone]
    expect(json["group_permissions"]).to include(
      hash_including(
        "permission_type" => CategoryGroup.permission_types[:create_post],
        "permission" => "create_post",
        "group_name" => everyone_group.name,
        "group_id" => everyone_group.id,
      ),
    )
  end

  it "returns not found when category is not visible and no joinable group exists" do
    sign_in(user)
    group.update!(public_admission: false, allow_membership_requests: false)

    get "/c/#{private_category.id}/reach-and-rights", xhr: true

    expect(response.status).to eq(404)
  end

  it "returns permissions when category is not visible but a group is joinable" do
    sign_in(user)
    group.update!(public_admission: true)

    get "/c/#{private_category.id}/reach-and-rights", xhr: true

    expect(response.status).to eq(200)
    json = response.parsed_body
    expect(json["category_id"]).to eq(private_category.id)
    expect(json["group_permissions"]).not_to be_empty
  end

  it "respects the min_trust_level setting" do
    SiteSetting.discourse_reach_and_rights_min_trust_level = 1
    user.update!(trust_level: 0)
    group.add(user)
    sign_in(user)

    get "/c/#{category.id}/reach-and-rights", xhr: true

    expect(response.status).to eq(403)

    user.update!(trust_level: 1)
    get "/c/#{category.id}/reach-and-rights", xhr: true
    expect(response.status).to eq(200)
  end

  it "returns localized group names" do
    user.update!(locale: "de")
    sign_in(user)
    group.add(user)

    category.set_permissions(:admins => :full, group.name => :readonly)
    category.save!
    category.update!(read_restricted: false)

    get "/c/#{category.id}/reach-and-rights", xhr: true

    expect(response.status).to eq(200)
    json = response.parsed_body

    admin_perm = json["group_permissions"].find { |p| p["group_name"] == "admins" }
    expect(admin_perm["group_display_name"]).to eq("Admins")

    everyone_perm =
      json["group_permissions"].find { |p| p["group_id"] == Group::AUTO_GROUPS[:everyone] }
    expect(everyone_perm["group_display_name"]).to eq("jeder")
  end
end
