# frozen_string_literal: true

# name: discourse-reach-and-rights
# about: display category group permissions and reach to users via a bbcode tag
# meta_topic_id: TODO
# version: 0.1.0
# authors: gemini-3-flash-preview prompted and debugged by Thomas Kalka
# url: https://github.com/thoka/discourse-reach-and-rights
# required_version: 2.7.0

enabled_site_setting :discourse_reach_and_rights_enabled

register_asset "stylesheets/discourse-reach-and-rights.scss"

register_svg_icon "square-check"
register_svg_icon "far-square"
register_svg_icon "eye"
register_svg_icon "envelope"
register_svg_icon "plus"
register_svg_icon "user-plus"
register_svg_icon "paper-plane"
register_svg_icon "bell" if respond_to?(:register_svg_icon)
register_svg_icon "circle-exclamation" if respond_to?(:register_svg_icon)
register_svg_icon "circle-dot" if respond_to?(:register_svg_icon)
register_svg_icon "bell-slash" if respond_to?(:register_svg_icon)
register_svg_icon "far-bell" if respond_to?(:register_svg_icon)
register_svg_icon "d-watching"
register_svg_icon "d-tracking"
register_svg_icon "d-watching-first"
register_svg_icon "d-muted"
register_svg_icon "d-regular"
register_svg_icon "info-circle"
register_svg_icon "cog"
register_svg_icon "users"

module ::DiscourseReachAndRights
  PLUGIN_NAME = "discourse-reach-and-rights"
end

require_relative "lib/discourse_reach_and_rights/engine"
require_relative "lib/discourse_reach_and_rights/request_cache_middleware"

Rails.configuration.middleware.use ::DiscourseReachAndRights::RequestCacheMiddleware

after_initialize do
  require_relative "app/models/discourse_reach_and_rights/stat"
  require_relative "app/controllers/discourse_reach_and_rights/permissions_controller"
  require_relative "app/services/discourse_reach_and_rights/permissions_fetcher"
  require_relative "app/services/discourse_reach_and_rights/reach_calculator"
  require_relative "app/services/discourse_reach_and_rights/stats_store"
  require_relative "app/jobs/scheduled/update_reach_stats"

  %i[category basic_category].each do |s|
    add_to_serializer(s, :reach_and_rights) do
      return nil if !SiteSetting.discourse_reach_and_rights_enabled
      return nil if !scope&.user
      return nil if scope.user.trust_level < SiteSetting.discourse_reach_and_rights_min_trust_level

      # Der Fetcher sollte Request-Level Caching nutzen, um N+1 zu vermeiden
      result = DiscourseReachAndRights::PermissionsFetcher.call(category: object, guardian: scope)
      stats = DiscourseReachAndRights::StatsStore.stats_for(object.id)

      {
        category_id: object.id,
        category_name: object.name,
        category_url: object.url,
        group_permissions: result.permissions,
        category_notification_totals: result.category_notification_totals,
        reach_count: stats&.[](:reach_count) || 0,
        watching_count: stats&.[](:watching_count) || 0,
        watching_first_post_count: stats&.[](:watching_first_post_count) || 0,
      }
    end
  end

  add_to_serializer(:site, :categories) do
    cats = object.categories.map { |c| c.to_h }

    if SiteSetting.discourse_reach_and_rights_enabled && scope&.user &&
         scope.user.trust_level >= SiteSetting.discourse_reach_and_rights_min_trust_level
      stats =
        DiscourseReachAndRights::Stat.all.each_with_object({}) do |s, h|
          h[s.category_id] = {
            reach_count: s.reach_count,
            watching_count: s.watching_count,
            watching_first_post_count: s.watching_first_post_count,
          }
        end

      cats.each do |c|
        if stat = stats[c[:id]]
          c[:reach_and_rights] = (c[:reach_and_rights] || {}).merge(stat)
        end
      end
    end

    cats
  end

  Discourse::Application.routes.prepend do
    get "/c/:category_id/reach-and-rights" => "discourse_reach_and_rights/permissions#show",
        :constraints => {
          format: :json,
        }
  end

  if DiscourseReachAndRights::Stat.count == 0 && SiteSetting.discourse_reach_and_rights_enabled
    Scheduler::Defer.later("Initial Reach and Rights calculation") do
      DiscourseReachAndRights::ReachCalculator.run
    end
  end
end
