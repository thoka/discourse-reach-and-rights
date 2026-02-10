# frozen_string_literal: true

require File.expand_path("../../../../spec/rails_helper", __dir__)

RSpec.describe PrettyText do
  before { enable_current_plugin }

  it "renders show-permissions bbcode with data attributes" do
    cooked = PrettyText.cook("[show-permissions category=5]")

    expect(cooked).to match_html(
      "<p><span class=\"discourse-reach-and-rights\" data-category=\"5\"></span></p>",
    )
  end
end
