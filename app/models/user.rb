class User < ApplicationRecord
  include Party

  MANDATORY_TWO_FACTOR_ROLES = %w[owner admin].freeze

  # Include default devise modules. Others available are:
  # :confirmable, :lockable and :omniauthable
  devise :two_factor_authenticatable, :two_factor_backupable, :registerable,
         :recoverable, :timeoutable, :validatable

  has_many :entity_users
  has_many :webauthn_credentials, dependent: :destroy

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

  # Registering a passkey IS "going passwordless" - not a separate flag.
  # Removing the last credential naturally restores password sign-in.
  def passwordless?
    webauthn_credentials.exists?
  end

  # Lazily generated, stable WebAuthn user handle.
  def webauthn_id
    self[:webauthn_id] || begin
      id = WebAuthn.generate_user_id
      update_column(:webauthn_id, id) # rubocop:disable Rails/SkipsModelValidations
      id
    end
  end
end
