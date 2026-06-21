# frozen_string_literal: true

class Department < ApplicationRecord
  belongs_to :entity
  has_many :entity_user_departments, dependent: :destroy
  has_many :entity_users, through: :entity_user_departments
  has_many :documents, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :entity_id }

  scope :default, -> { where(is_default: true) }

  def default?
    is_default
  end
end
