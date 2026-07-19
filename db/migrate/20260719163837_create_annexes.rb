class CreateAnnexes < ActiveRecord::Migration[8.1]
  def change
    create_table :annexes do |t|
      t.references :document, null: false, foreign_key: true

      t.timestamps
    end
  end
end
