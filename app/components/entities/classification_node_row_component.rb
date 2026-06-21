# frozen_string_literal: true

module Entities
  class ClassificationNodeRowComponent < ViewComponent::Base
    INDENT_CLASS = {
      1 => "",
      2 => "pl-4",
      3 => "pl-8",
      4 => "pl-12"
    }.freeze

    def initialize(node:, mode:, current_entity:, document: nil, active_node_id: nil, can_manage: false, document_counts: {})
      @node = node
      @mode = mode
      @current_entity = current_entity
      @document = document
      @active_node_id = active_node_id
      @can_manage = can_manage
      @document_counts = document_counts
    end

    def sorted_children
      ClassificationNode.sort_by_code(@node.children.to_a)
    end

    def indent_class
      INDENT_CLASS.fetch(@node.depth, "")
    end

    def document_count
      @document_counts[@node.id] || 0
    end

    def active?
      @active_node_id.to_s == @node.id.to_s
    end

    def classified_here?
      @document && @document.classification_node_id == @node.id
    end

    def searchable_text
      "#{@node.code} #{@node.name}".downcase
    end

    def add_child_allowed?
      @can_manage && @node.depth < ClassificationNode::MAX_DEPTH
    end

    def child_attrs(child)
      { node: child, mode: mode, current_entity: current_entity, document: document,
        active_node_id: active_node_id, can_manage: can_manage, document_counts: document_counts }
    end

    private

    attr_reader :node, :mode, :current_entity, :document, :can_manage, :active_node_id, :document_counts
  end
end
