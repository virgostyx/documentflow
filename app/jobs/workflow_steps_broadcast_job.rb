# frozen_string_literal: true

class WorkflowStepsBroadcastJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(user_id, document_id)
    user = User.find(user_id)
    document = Document.find(document_id)

    target = ActionView::RecordIdentifier.dom_id(document, :workflow_steps)
    component_html = ApplicationController.render(
      Workflow::StepsComponent.new(document: document, current_user: user),
      layout: false
    )
    content = %(<div id="#{target}">#{component_html}</div>)

    stream = Turbo::StreamsChannel.turbo_stream_action_tag(:replace, target: target, template: content)
    Turbo::StreamsChannel.broadcast_stream_to(document.entity, user, :workflow, content: stream)
  end
end
