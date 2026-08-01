class CreateSignatureImages < ActiveRecord::Migration[8.1]
  def change
    create_table :signature_images do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.text :image_data, null: false
      t.string :content_type, null: false
      t.integer :byte_size, null: false

      t.timestamps
    end
  end
end
