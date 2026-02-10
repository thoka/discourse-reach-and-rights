# frozen_string_literal: true

module Jobs
  class UpdateReachStats < ::Jobs::Scheduled
    every 1.hour

    def execute(args)
      return if !SiteSetting.discourse_reach_and_rights_enabled

      ::DiscourseReachAndRights::ReachCalculator.run
    end
  end
end
