# frozen_string_literal: true

module ::DiscourseReachAndRights
  class ReachCalculator
    def self.run
      new.calculate_all
    end

    def calculate_all
      reach_counts = calculate_reach_bulk
      watching_counts = calculate_watching_bulk
      # watching_first_post needs both watching and specific watchers
      watching_first_counts = calculate_watching_first_bulk(watching_counts)

      # Get all categories to ensure we handle those with 0 stats
      category_ids = Category.pluck(:id)

      updates = []

      category_ids.each do |c_id|
        reach = reach_counts[c_id] || 0
        watching = watching_counts[c_id] || 0
        watching_first = watching_first_counts[c_id] || 0

        stat = Stat.ensure_for(c_id)

        if stat.reach_count != reach || stat.watching_count != watching ||
             stat.watching_first_post_count != watching_first
          stat.update!(
            reach_count: reach,
            watching_count: watching,
            watching_first_post_count: watching_first,
          )
          updates << {
            category_id: c_id,
            reach_count: reach,
            watching_count: watching,
            watching_first_post_count: watching_first,
          }
        end
      end

      publish_updates(updates) if updates.any?
    end

    private

    def calculate_reach_bulk
      DB.query(<<~SQL).each_with_object({}) { |r, h| h[r.category_id] = r.count }
        SELECT cg.category_id, COUNT(DISTINCT gu.user_id) as count
        FROM category_groups cg
        JOIN group_users gu ON gu.group_id = cg.group_id
        GROUP BY cg.category_id
      SQL
    end

    def calculate_watching_bulk
      watching_level = CategoryUser.notification_levels[:watching]
      muted_level = CategoryUser.notification_levels[:muted]

      DB
        .query(<<~SQL, watching_level: watching_level, muted_level: muted_level)
        SELECT cg.category_id, COUNT(DISTINCT u.id) as count
        FROM users u
        JOIN user_options uo ON uo.user_id = u.id
        JOIN group_users gu ON gu.user_id = u.id
        JOIN category_groups cg ON cg.group_id = gu.group_id
        LEFT JOIN category_users cu ON cu.user_id = u.id AND cu.category_id = cg.category_id
        WHERE (cu.notification_level = :watching_level)
           OR (uo.mailing_list_mode = true AND (cu.notification_level IS NULL OR cu.notification_level != :muted_level))
        GROUP BY cg.category_id
      SQL
        .each_with_object({}) { |r, h| h[r.category_id] = r.count }
    end

    def calculate_watching_first_bulk(watching_counts)
      first_post_level = CategoryUser.notification_levels[:watching_first_post]
      watching_level = CategoryUser.notification_levels[:watching]
      muted_level = CategoryUser.notification_levels[:muted]

      # Counts for those specifically on "watching_first_post" who are NOT already in mailing list/watching
      results =
        DB
          .query(
            <<~SQL,
        SELECT cg.category_id, COUNT(DISTINCT u.id) as count
        FROM users u
        JOIN user_options uo ON uo.user_id = u.id
        JOIN group_users gu ON gu.user_id = u.id
        JOIN category_groups cg ON cg.group_id = gu.group_id
        JOIN category_users cu ON cu.user_id = u.id AND cu.category_id = cg.category_id
        WHERE cu.notification_level = :first_post_level
          AND NOT (uo.mailing_list_mode = true AND (cu.notification_level IS NULL OR cu.notification_level != :muted_level))
          AND NOT (cu.notification_level = :watching_level)
        GROUP BY cg.category_id
      SQL
            first_post_level: first_post_level,
            watching_level: watching_level,
            muted_level: muted_level,
          )
          .each_with_object({}) { |r, h| h[r.category_id] = r.count }

      # Combine with watching_counts
      watching_counts.each_with_object(results.dup) do |(c_id, count), h|
        h[c_id] = (h[c_id] || 0) + count
      end
    end

    def publish_updates(updates)
      # Publish as a single batch update to minimize MessageBus overhead
      MessageBus.publish("/reach-and-rights/stats", { updates: updates })
    end
  end
end
