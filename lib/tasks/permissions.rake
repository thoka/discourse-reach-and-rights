# frozen_string_literal: true

namespace :discourse_reach_and_rights do
  desc "Append [reach-and-rights] tag to all category descriptions that don't have it yet"
  task append_to_categories: :environment do
    puts "Scanning categories..."
    updated = 0

    Category
      .where.not(topic_id: nil)
      .find_each do |category|
        topic = category.topic
        if topic.nil?
          puts "Skipping #{category.name}: topic not found"
          next
        end

        post = topic.first_post
        if post.nil?
          puts "Skipping #{category.name}: first post not found"
          next
        end

        next if post.raw.include?("[reach-and-rights]") || post.raw.include?("[show-permissions]")

        puts "Updating category '#{category.name}' (Topic: #{topic.id})"

        new_raw = post.raw.dup
        new_raw << "\n\n" unless new_raw.end_with?("\n\n")
        new_raw << "[reach-and-rights]"

        # Use skip_validations and skip_revision to avoid noise
        post.update_columns(raw: new_raw)
        post.rebake!
        updated += 1
      end

    puts "Done! Updated #{updated} category descriptions."
  end
end
