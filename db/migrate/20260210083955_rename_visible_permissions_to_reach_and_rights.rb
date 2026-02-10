# frozen_string_literal: true

class RenameVisiblePermissionsToReachAndRights < ActiveRecord::Migration[7.0]
  def up
    settings = %w[
      enabled
      default_view
      color_create
      color_reply
      color_see
      min_trust_level
      cache_ttl_minutes
    ]

    settings.each do |setting|
      old_name = "discourse_visible_permissions_#{setting}"
      new_name = "discourse_reach_and_rights_#{setting}"

      execute <<~SQL
        INSERT INTO site_settings (name, value, data_type, created_at, updated_at)
        SELECT '#{new_name}', value, data_type, NOW(), NOW()
        FROM site_settings
        WHERE name = '#{old_name}'
        ON CONFLICT (name) DO NOTHING
      SQL
    end
  end

  def down
    # Optional: rollback logic if needed
  end
end
