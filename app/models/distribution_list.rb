# frozen_string_literal: true

class DistributionList < ApplicationRecord
  belongs_to :user
  has_many :distribution_list_members, -> { order(:position) },
           dependent: :destroy, inverse_of: :distribution_list

  accepts_nested_attributes_for :distribution_list_members, allow_destroy: true

  validates :name, presence: true, uniqueness: { scope: :user_id }
end
