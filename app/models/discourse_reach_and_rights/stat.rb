# frozen_string_literal: true

module ::DiscourseReachAndRights
  class Stat < ActiveRecord::Base
    self.table_name = "reach_and_rights_stats"

    belongs_to :category

    validates :category_id, presence: true, uniqueness: true

    def self.ensure_for(category_id)
      find_or_create_by!(category_id: category_id)
    end
  end
end
