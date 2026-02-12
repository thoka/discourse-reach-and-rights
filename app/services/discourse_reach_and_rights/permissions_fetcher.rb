# frozen_string_literal: true

module DiscourseReachAndRights
  class PermissionsFetcher
    include Service::Base

    step :build_permissions

    private

    def build_permissions(category:, guardian:)
      user = guardian.user

      # 1. Get all relevant group IDs
      permission_group_ids = category.category_groups.pluck(:group_id)
      notification_group_ids =
        GroupCategoryNotificationDefault.where(category: category).pluck(:group_id)
      all_group_ids = (permission_group_ids + notification_group_ids).uniq

      # 2. Cache expensive calculations per category
      # Invalidate if category or its groups/notifications change
      cache_key = "reach-and-rights:cat-data:#{category.id}:#{category.updated_at.to_i}"
      ttl = SiteSetting.discourse_reach_and_rights_cache_ttl_minutes

      fetch_data =
        proc do
          # Fetch data for all potentially relevant groups
          groups = Group.where(id: all_group_ids).to_a

          # Calculate totals for the entire category (Unique Reach)
          category_notification_totals = calculate_category_notification_totals(category)

          # Calculate levels for each group efficiently
          group_notification_counts =
            calculate_group_notification_counts(all_group_ids, category.id)

          group_user_counts =
            Group
              .where(id: all_group_ids)
              .joins(group_users: :user)
              .where("users.id > 0 AND users.active AND NOT users.staged")
              .group(:group_id)
              .count

          group_data =
            groups.map do |group|
              notification_default =
                group.group_category_notification_defaults.find do |nd|
                  nd.category_id == category.id
                end
              category_group = group.category_groups.find { |cg| cg.category_id == category.id }

              user_count =
                if group.id == Group::AUTO_GROUPS[:everyone]
                  if category.read_restricted?
                    category_notification_totals[:total_reach]
                  else
                    User.human_users.activated.not_staged.count
                  end
                else
                  group_user_counts[group.id] || 0
                end

              {
                group_id: group.id,
                group_name: group.name,
                group_full_name: group.full_name,
                public_admission: group.public_admission,
                allow_membership_requests: group.allow_membership_requests,
                user_count: user_count,
                permission_type:
                  category_group&.permission_type || CategoryGroup.permission_types[:readonly],
                notification_level: notification_default&.notification_level,
                notification_levels:
                  if group.id == Group::AUTO_GROUPS[:everyone]
                    category_notification_totals
                  else
                    group_notification_counts[group.id]
                  end,
              }
            end

          { group_data: group_data, category_notification_totals: category_notification_totals }
        end

      cached_data =
        if ttl > 0
          Discourse.cache.fetch(cache_key, expires_in: ttl.minutes, &fetch_data)
        else
          fetch_data.call
        end

      # 3. Process groups and handle hidden groups
      all_groups = Group.where(id: all_group_ids).to_a
      visible_group_ids =
        Group.visible_groups(user, nil, include_everyone: true).where(id: all_group_ids).pluck(:id)

      permissions =
        cached_data[:group_data]
          .map do |gd|
            is_visible = visible_group_ids.include?(gd[:group_id])
            group_obj = all_groups.find { |g| g.id == gd[:group_id] }
            next if group_obj.blank?

            is_member = user && user.group_ids.include?(gd[:group_id])

            if is_visible
              {
                permission_type: gd[:permission_type],
                permission: CategoryGroup.permission_types.key(gd[:permission_type]),
                group_name: gd[:group_name],
                group_display_name: localized_group_name(gd[:group_name], gd[:group_full_name]),
                group_id: gd[:group_id],
                can_join: user && gd[:public_admission] && !is_member,
                can_request:
                  user && gd[:allow_membership_requests] && !is_member &&
                    !GroupRequest.where(group_id: gd[:group_id], user: user).exists?,
                is_member: is_member,
                group_url: "/g/#{gd[:group_name]}",
                notification_level: gd[:notification_level],
                notification_levels: gd[:notification_levels],
                user_count: gd[:user_count],
                is_hidden: false,
              }
            else
              {
                permission_type: gd[:permission_type],
                permission: CategoryGroup.permission_types.key(gd[:permission_type]),
                group_name: nil,
                group_display_name: I18n.t("discourse_reach_and_rights.hidden_group"),
                group_id: nil,
                can_join: false,
                can_request: false,
                is_member: is_member,
                group_url: nil,
                notification_level: gd[:notification_level],
                notification_levels: gd[:notification_levels],
                user_count: gd[:user_count],
                is_hidden: true,
              }
            end
          end
          .compact

      # 4. Handle 'everyone' group if it's missing (e.g. category not read_restricted)
      if !category.read_restricted &&
           !permissions.any? { |p| p[:group_id] == Group::AUTO_GROUPS[:everyone] }
        everyone_group = Group[:everyone]
        permissions.unshift(
          {
            permission_type: CategoryGroup.permission_types[:create_post],
            permission: "create_post",
            group_name: "everyone",
            group_display_name: localized_group_name("everyone", everyone_group&.full_name),
            group_id: Group::AUTO_GROUPS[:everyone],
            can_join: false,
            can_request: false,
            is_member: true,
            group_url: "/g/everyone",
            notification_level: nil,
            notification_levels: cached_data[:category_notification_totals],
            user_count: User.human_users.activated.not_staged.count,
          },
        )
      end

      permissions.sort_by! { |p| [p[:permission_type], p[:group_display_name] || ""] }

      context[:permissions] = permissions
      context[:category_notification_totals] = cached_data[:category_notification_totals]
    end

    def calculate_category_notification_totals(category)
      # 1. Identify all users who can see this category
      if category.read_restricted?
        # Only users in groups that have at least "See" permission
        allowed_group_ids = category.category_groups.pluck(:group_id)
        return { total_reach: 0 } if allowed_group_ids.empty?
        user_ids_with_access_subquery =
          "SELECT gu.user_id FROM group_users gu JOIN users u ON u.id = gu.user_id WHERE gu.group_id IN (#{allowed_group_ids.join(",")}) AND u.id > 0 AND u.active AND NOT u.staged"
      else
        # All real, active, human users
        user_ids_with_access_subquery =
          "SELECT id as user_id FROM users WHERE id > 0 AND active AND NOT staged"
      end

      # 2. Highest notification level for these users
      sql = <<~SQL
        WITH AccessUsers AS (
          #{user_ids_with_access_subquery}
        ),
        AllSettings AS (
          -- Explicit overrides
          SELECT cu.user_id, cu.notification_level 
          FROM category_users cu
          WHERE cu.category_id = :category_id
          AND cu.user_id IN (SELECT user_id FROM AccessUsers)
          
          UNION ALL
          
          -- Group defaults
          SELECT gu.user_id, gd.notification_level
          FROM group_category_notification_defaults gd
          JOIN group_users gu ON gu.group_id = gd.group_id
          WHERE gd.category_id = :category_id
          AND gu.user_id IN (SELECT user_id FROM AccessUsers)
        ),
        TargetUsers AS (
          SELECT au.user_id, 
                 CASE MAX(CASE s.notification_level
                           WHEN 3 THEN 100 -- Watching (Highest priority)
                           WHEN 4 THEN 80  -- Watching First Post
                           WHEN 2 THEN 60  -- Tracking
                           WHEN 1 THEN 40  -- Regular
                           WHEN 0 THEN 20  -- Muted
                           ELSE 0 END)
                   WHEN 100 THEN 3
                   WHEN 80  THEN 4
                   WHEN 60  THEN 2
                   WHEN 40  THEN 1
                   WHEN 20  THEN 0
                   ELSE NULL
                 END as level
          FROM AccessUsers au
          LEFT JOIN AllSettings s ON s.user_id = au.user_id
          GROUP BY au.user_id
        )
        SELECT COALESCE(level, :regular_level) as final_level, COUNT(*) as count
        FROM TargetUsers
        GROUP BY final_level
      SQL

      counts = Hash.new(0)
      res = DB.query(sql, category_id: category.id, regular_level: NotificationLevels.all[:regular])
      res.each { |row| counts[row.final_level.to_i] = row.count.to_i }

      counts[:total_reach] = counts.values.sum
      counts
    end

    def calculate_group_notification_counts(group_ids, category_id)
      return {} if group_ids.blank?
      default_level = NotificationLevels.all[:regular]

      sql = <<~SQL
        SELECT gu.group_id, 
               COALESCE(cu.notification_level, gnd.notification_level, :default_level) as final_notification_level, 
               COUNT(*) as count
        FROM group_users gu
        JOIN users u ON u.id = gu.user_id
        LEFT JOIN group_category_notification_defaults gnd ON gnd.group_id = gu.group_id AND gnd.category_id = :category_id
        LEFT JOIN category_users cu ON cu.user_id = gu.user_id AND cu.category_id = :category_id
        WHERE gu.group_id IN (:group_ids) AND u.id > 0 AND u.active AND NOT u.staged
        GROUP BY gu.group_id, final_notification_level
      SQL

      results = Hash.new { |h, k| h[k] = Hash.new(0) }
      DB
        .query(sql, group_ids: group_ids, category_id: category_id, default_level: default_level)
        .each do |row|
          results[row.group_id.to_i][row.final_notification_level.to_i] = row.count.to_i
        end
      results
    end

    def localized_group_name(name, full_name)
      return full_name if full_name.present?

      I18n.t(
        "discourse_reach_and_rights.#{name}",
        default: ["groups.default_names.#{name}".to_sym, name.humanize],
      )
    end
  end
end
