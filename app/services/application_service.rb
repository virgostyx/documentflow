# frozen_string_literal: true

# Base class for all service organizers
# Uses LightService to orchestrer des workflows métier composés d'Actions atomiques
class ApplicationService
  extend LightService::Organizer

  class ValidationError < StandardError; end
  class PermissionError < StandardError; end
  class BusinessLogicError < StandardError; end

  # Point d'entrée de tous les organizers
  # Usage: MyOrganizer.call(param1: value1, param2: value2)
  def self.call(**args)
    result = nil
    ActiveRecord::Base.transaction do
      result = with(**args).reduce(steps)
      raise ActiveRecord::Rollback if result.failure?
    end
    result
  end

  # Ajoute l'étape d'audit logging à la fin d'une liste d'actions
  # Usage:
  #   def self.steps
  #     with_audit_logging([MyAction1, MyAction2])
  #   end
  def self.with_audit_logging(steps_array)
    steps_array + [ Shared::Actions::LogAuditEvent ]
  end

  # DSL déclaratif : `workflow_steps Action1, Action2, audit_log: false`
  def self.workflow_steps(*actions, audit_log: true)
    step_list = actions.flatten
    define_singleton_method(:steps) do
      audit_log ? with_audit_logging(step_list) : step_list
    end
  end

  def self.steps
    raise NotImplementedError, "Subclasses must define steps"
  end
end
