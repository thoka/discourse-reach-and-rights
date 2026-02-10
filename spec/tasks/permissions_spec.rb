# frozen_string_literal: true

require File.expand_path("../../../../spec/rails_helper", __dir__)
require "rake"

describe "discourse_reach_and_rights rake tasks" do
  fab!(:admin)

  before do
    Rake.application.rake_require "tasks/reach-and-rights",
                                  ["#{Rails.root}/plugins/discourse-reach-and-rights/lib"]
    Rake::Task.define_task(:environment)
  end

  describe "append_to_categories" do
    let(:rake_task) { Rake::Task["discourse_reach_and_rights:append_to_categories"] }

    it "appends the tag to the first post of the category topic" do
      category = Category.create!(name: "Rake Category 1", user: admin)
      post = category.topic.first_post
      expect(post.raw).not_to include("[show-permissions]")

      rake_task.invoke
      rake_task.reenable

      expect(post.reload.raw).to include("[show-permissions]")
    end

    it "does not append the tag if it already exists" do
      category = Category.create!(name: "Rake Category 2", user: admin)
      post = category.topic.first_post
      original_raw = "This is a description with [show-permissions] tag already."
      post.update!(raw: original_raw)

      rake_task.invoke
      rake_task.reenable

      expect(post.reload.raw).to eq(original_raw)
    end
  end
end
