# frozen_string_literal: true

module ::DiscourseReachAndRights
  class StatsStore
    CACHE_DURATION = 30.minutes

    def self.cache_key
      "reach_and_rights_stats_#{Discourse.git_version}"
    end

    def self.all_stats
      Discourse
        .cache
        .fetch(cache_key, expires_in: CACHE_DURATION) do
          Stat
            .pluck(:category_id, :reach_count, :watching_count, :watching_first_post_count)
            .to_h do |s|
              [s[0], { reach_count: s[1], watching_count: s[2], watching_first_post_count: s[3] }]
            end
        end
    end

    def self.stats_for(category_id)
      all_stats[category_id]
    end

    def self.clear!
      Discourse.cache.delete(cache_key)
    end

    def self.refresh!
      clear!
      all_stats
    end
  end
end
