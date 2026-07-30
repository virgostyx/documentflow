class User < ApplicationRecord
  include Party

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :timeoutable, :validatable

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true

  # Methods
  def full_name
    "#{first_name} #{last_name}"
  end
end
