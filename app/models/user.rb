class User < ApplicationRecord
  include Party

  MANDATORY_TWO_FACTOR_ROLES = %w[owner admin].freeze

  # Include default devise modules. Others available are:
  # :confirmable, :lockable and :omniauthable
  devise :two_factor_authenticatable, :two_factor_backupable, :registerable,
         :recoverable, :timeoutable, :validatable

  has_many :entity_users
  has_many :webauthn_credentials, dependent: :destroy
  has_one :signature_image, dependent: :destroy

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :external_email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true, allow_blank: true

  # Callbacks
  before_validation :normalize_external_email

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

  private

  def normalize_external_email
    self.external_email = external_email.strip.downcase if external_email.present?
  end
end
