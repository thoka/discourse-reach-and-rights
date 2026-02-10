# frozen_string_literal: true

require File.expand_path("../../../../spec/rails_helper", __dir__)

RSpec.describe "Reach and Rights", type: :system do
  fab!(:admin)
  fab!(:category)
  fab!(:group)
  fab!(:user)

  before do
    SiteSetting.discourse_reach_and_rights_enabled = true
    category.set_permissions(group.name => :create_post)
    category.save!
    group.add(user)
    sign_in(user)
  end

  it "renders category permissions when the [reach-and-rights] tag is used" do
    post = Fabricate(:post, raw: "[reach-and-rights category=#{category.id}]")

    visit post.url

    expect(page).to have_css(".discourse-reach-and-rights-table", wait: 5)
    expect(page).to have_content(
      I18n.t("js.discourse_reach_and_rights.table_title", category_name: category.name),
    )
  end

  it "renders category permissions when the old [show-permissions] tag is used" do
    post = Fabricate(:post, raw: "[show-permissions category=#{category.id}]")

    visit post.url

    # Wait for the decorator to run and fetch data
    expect(page).to have_css(".discourse-reach-and-rights-table", wait: 5)
    expect(page).to have_css(".discourse-reach-and-rights-title", wait: 5)

    expect(page).to have_content(
      I18n.t("js.discourse_reach_and_rights.table_title", category_name: category.name),
    )

    within ".discourse-reach-and-rights-table" do
      expect(page).to have_content("My group 0")
    end
  end

  it "does not render anything when the user is not logged in" do
    # Simply don't sign in (the before block signs in by default, so we need to override/adjust)
    post = Fabricate(:post, raw: "[show-permissions category=#{category.id}]")

    using_session("anonymous") do
      visit post.url
      expect(page).to have_css(".discourse-reach-and-rights", visible: false)
      expect(page).not_to have_css(".discourse-reach-and-rights-table")
    end
  end

  it "renders the current category permissions when the BBCode is used without a category ID" do
    topic = Fabricate(:topic, category: category)
    post = Fabricate(:post, topic: topic, raw: "[show-permissions]")

    visit post.url

    expect(page).to have_css(".discourse-reach-and-rights-table", wait: 5)

    within ".discourse-reach-and-rights-table" do
      expect(page).to have_content("My group 0")
    end
  end

  it "renders the short view when requested via BBCode" do
    post = Fabricate(:post, raw: "[show-permissions category=#{category.id} view=short]")

    visit post.url

    expect(page).to have_css(".view-short", wait: 5)
    expect(page).to have_css(".discourse-reach-and-rights-short-container")

    within ".view-short" do
      expect(page).to have_content("My group 0")
    end
  end

  it "respects the default view site setting" do
    SiteSetting.discourse_reach_and_rights_default_view = "short"
    post = Fabricate(:post, raw: "[show-permissions category=#{category.id}]")

    visit post.url

    expect(page).to have_css(".view-short", wait: 5)
  end

  it "shows an error if the category is not found or inaccessible" do
    private_group = Fabricate(:group)
    private_category = Fabricate(:private_category, group: private_group) # user not in group
    post = Fabricate(:post, raw: "[show-permissions category=#{private_category.id}]")

    visit post.url

    expect(page).to have_content(I18n.t("js.discourse_reach_and_rights.load_error"), wait: 5)
  end

  it "renders localized group names for automatic groups in German" do
    user.update!(locale: "de")
    category.set_permissions(:admins => :full, group.name => :readonly)
    category.save!
    category.update!(read_restricted: false)

    post = Fabricate(:post, raw: "[show-permissions category=#{category.id}]")

    visit post.url

    expect(page).to have_css(".discourse-reach-and-rights-table", wait: 5)

    within ".discourse-reach-and-rights-table" do
      expect(page).to have_content("Admins")
      expect(page).to have_content("jeder")

      # Check for tooltips (title attributes)
      expect(page).to have_css(
        ".cell[title='#{I18n.t("js.category.permissions.see", locale: :de)}']",
      )
      expect(page).to have_css(
        ".cell[title='#{I18n.t("js.category.permissions.reply", locale: :de)}']",
      )
      expect(page).to have_css(
        ".cell[title='#{I18n.t("js.category.permissions.create", locale: :de)}']",
      )
    end
  end
end
