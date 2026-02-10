# frozen_string_literal: true

class CreateReachAndRightsStats < ActiveRecord::Migration[7.0]
  def change
    create_table :reach_and_rights_stats do |t|
      t.integer :category_id, null: false
      t.integer :reach_count, default: 0, null: false
      t.integer :watching_count, default: 0, null: false
      t.integer :watching_first_post_count, default: 0, null: false
      t.timestamps

      t.index :category_id, unique: true
    end
  end
end
