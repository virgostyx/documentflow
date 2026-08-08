# frozen_string_literal: true

# Live-updates the "Dispatch status" panel on a document's show page as
# AddresseeNotificationJob/CcNotificationJob log dispatch_sent/dispatch_failed
# events, so a viewer doesn't need to reload to see "Pending" flip to "Sent".
class DispatchStatusBroadcastJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(document_id)
    document = Document.find(document_id)

    target = ActionView::RecordIdentifier.dom_id(document, :dispatch_status)
    component_html = ApplicationController.render(
      Documents::DispatchStatusComponent.new(document: document),
      layout: false
    )

    stream = Turbo::StreamsChannel.turbo_stream_action_tag(:replace, target: target, template: component_html)
    Turbo::StreamsChannel.broadcast_stream_to(document, :dispatch_status, content: stream)
  end
end
