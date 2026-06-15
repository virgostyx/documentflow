class User < ApplicationRecord
  include Party

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true

  # Methods
  def full_name
    "#{first_name} #{last_name}"
  end
end
