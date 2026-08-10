class AddSkipPdfConversionToAnnexes < ActiveRecord::Migration[8.1]
  def change
    add_column :annexes, :skip_pdf_conversion, :boolean, default: false, null: false
  end
end
