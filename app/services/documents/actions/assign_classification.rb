# frozen_string_literal: true

module Documents
  module Actions
    class AssignClassification < ApplicationAction
      expects :document, :current_user
      expects :classification_node, default: nil

      executed do |ctx|
        node = ctx.classification_node
        document = ctx.document

        if document.update(classification_node: node)
          ctx[:user] = ctx.current_user
          ctx[:auditable] = document
          ctx[:action] = "classify"
          ctx[:audit_changes] = { classification_node_id: document.classification_node_id }

          succeed_with!(ctx, node ? "Document filed under #{node.code} — #{node.name}." : "Document unfiled.")
        else
          fail_with!(ctx, document.errors.full_messages.to_sentence)
        end
      end
    end
  end
end
