class CreatePopulations < ActiveRecord::Migration
  def change
    create_table :populations do |t|
      t.string  :county,    index: true
      t.integer :year,      index: true
      t.string  :race,      index: true
      t.string  :gender,    index: true
      t.string  :age_group, index: true
      t.integer :estimate
    end
  end
end
