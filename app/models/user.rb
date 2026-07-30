class User < ApplicationRecord
  include Party

  MANDATORY_TWO_FACTOR_ROLES = %w[owner admin].freeze

  # Include default devise modules. Others available are:
  # :confirmable, :lockable and :omniauthable
  devise :two_factor_authenticatable, :two_factor_backupable, :registerable,
         :recoverable, :timeoutable, :validatable

  has_many :entity_users

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true

  # Methods
  def full_name
    "#{first_name} #{last_name}"
  end

  def two_factor_required?
    super_admin? || entity_users.active.where(role: MANDATORY_TWO_FACTOR_ROLES).exists?
  end
end
