# frozen_string_literal: true

namespace :reach_and_rights do
  desc "Recalculate reach and rights statistics"
  task recalculate_stats: :environment do
    require "benchmark"

    puts I18n.t("discourse_reach_and_rights.recalculate_stats.recalculating")

    updates = nil
    time =
      Benchmark.measure do
        updates = ::DiscourseReachAndRights::ReachCalculator.run
        ::DiscourseReachAndRights::ReachCalculator.publish_updates(updates) if updates.any?
      end

    puts I18n.t("discourse_reach_and_rights.recalculate_stats.finished")
    puts I18n.t("discourse_reach_and_rights.recalculate_stats.time_taken", time: time.real.round(4))
    puts ""

    if updates.any?
      puts I18n.t("discourse_reach_and_rights.recalculate_stats.updates_performed")
      updates.each do |update|
        category = Category.find_by(id: update[:category_id])
        name =
          category&.name ||
            I18n.t(
              "discourse_reach_and_rights.recalculate_stats.unknown_category",
              id: update[:category_id],
            )
        puts I18n.t(
               "discourse_reach_and_rights.recalculate_stats.update_detail",
               name: name,
               reach: update[:reach_count],
               watching: update[:watching_count],
               watching_first: update[:watching_first_post_count],
             )
      end
      puts ""
    else
      puts I18n.t("discourse_reach_and_rights.recalculate_stats.no_updates")
      puts ""
    end

    puts I18n.t("discourse_reach_and_rights.recalculate_stats.summary_title")
    puts I18n.t("discourse_reach_and_rights.recalculate_stats.category_header").ljust(30) + " | " +
           I18n.t("discourse_reach_and_rights.recalculate_stats.reach_header").rjust(6) + " | " +
           I18n.t("discourse_reach_and_rights.recalculate_stats.watch_header").rjust(6) + " | " +
           I18n.t("discourse_reach_and_rights.recalculate_stats.watch_first_header").rjust(8)
    puts "-" * 60

    ::DiscourseReachAndRights::Stat
      .includes(:category)
      .order("categories.name ASC")
      .each do |stat|
        name =
          stat.category&.name ||
            I18n.t(
              "discourse_reach_and_rights.recalculate_stats.unknown_category",
              id: stat.category_id,
            )
        puts name.ljust(30) + " | " + stat.reach_count.to_s.rjust(6) + " | " +
               stat.watching_count.to_s.rjust(6) + " | " +
               stat.watching_first_post_count.to_s.rjust(8)
      end
  end
end
