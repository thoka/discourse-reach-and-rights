# frozen_string_literal: true

module ::DiscourseReachAndRights
  class StatsStore
    def self.stats_for(category_id)
      # Request-level cache using instances variable
      @stats ||= Stat.all.each_with_object({}) do |s, h|
        h[s.category_id] = {
          reach_count: s.reach_count,
          watching_count: s.watching_count,
          watching_first_post_count: s.watching_first_post_count
        }
      end
      @stats[category_id]
    end

    def self.clear!
      @stats = nil
    end
  end
end
