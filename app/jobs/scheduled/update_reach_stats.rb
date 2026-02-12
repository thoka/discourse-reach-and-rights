# frozen_string_literal: true

module Jobs
  class UpdateReachStats < ::Jobs::Scheduled
    every 5.minutes

    def execute(args)
      return if !SiteSetting.discourse_reach_and_rights_enabled

      ::DiscourseReachAndRights::ReachCalculator.run
    end
  end
end
