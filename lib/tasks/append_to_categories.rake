# frozen_string_literal: true

namespace :reach_and_rights do
  desc "Append [reach-and-rights] tag to all category descriptions that don't have it yet"
  task append_to_category_descriptions: :environment do
    puts I18n.t("discourse_reach_and_rights.append_to_categories.scanning")
    updated = 0

    Category
      .where.not(topic_id: nil)
      .find_each do |category|
        topic = category.topic
        if topic.nil?
          puts I18n.t(
                 "discourse_reach_and_rights.append_to_categories.skipping_topic",
                 name: category.name,
               )
          next
        end

        post = topic.first_post
        if post.nil?
          puts I18n.t(
                 "discourse_reach_and_rights.append_to_categories.skipping_post",
                 name: category.name,
               )
          next
        end

        next if post.raw.include?("[reach-and-rights]") || post.raw.include?("[show-permissions]")

        puts I18n.t(
               "discourse_reach_and_rights.append_to_categories.updating",
               name: category.name,
               id: topic.id,
             )

        new_raw = post.raw.dup
        new_raw << "\n\n" unless new_raw.end_with?("\n\n")
        new_raw << "[reach-and-rights]"

        # Use skip_validations and skip_revision to avoid noise
        post.update_columns(raw: new_raw)
        post.rebake!
        updated += 1
      end

    puts I18n.t("discourse_reach_and_rights.append_to_categories.done", count: updated)
  end
end
