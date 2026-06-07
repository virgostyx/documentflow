# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end

  protected

  # Resolves the Entity the record belongs to (or the record itself when it is an Entity).
  def entity
    record.is_a?(Entity) ? record : record.try(:entity)
  end

  def entity_user
    return nil unless user && entity

    @entity_user ||= EntityUser.active.find_by(entity: entity, user: user)
  end

  def entity_owner?
    entity_user&.owner? || false
  end

  def entity_admin?
    entity_user&.admin? || false
  end

  def entity_member?
    entity_user&.member? || false
  end

  def entity_guest?
    entity_user&.guest? || false
  end

  # True for any non-guest member of the entity (owner, admin or member).
  def entity_staff?
    entity_owner? || entity_admin? || entity_member?
  end
end
