# frozen_string_literal: true

module ApplicationHelper
  # Returns Tailwind classes for a sidebar nav link.
  # Marks the link active when the current request path matches any of the given paths.
  # With exact: true, only an exact match activates the link (used for "Overview" links
  # so they don't also light up for nested paths like /documents/mine or /documents/:id).
  def nav_class(*paths, exact: false)
    paths = paths.flatten
    active = if exact
      paths.include?(request.path)
    else
      paths.any? { |path| request.path == path || request.path.start_with?("#{path}/") }
    end

    base = "flex items-center gap-3 px-3 py-2 rounded-md text-sm font-medium transition-colors"
    if active
      "#{base} bg-primary-100 text-primary-700"
    else
      "#{base} text-gray-600 hover:bg-primary-50 hover:text-primary-700"
    end
  end

  # Renders a link for a sortable table column header. Clicking it sorts by the given
  # column, toggling direction if it's already the active sort column. Preserves other
  # query params (q, status, scope, ...) and resets pagination to the first page.
  def sortable_column_header(label, column)
    query = request.query_parameters
    current_column = query["sort"].presence || Document::DEFAULT_SORT_COLUMN
    current_direction = query["direction"].presence || Document::DEFAULT_SORT_DIRECTION

    next_direction = (current_column == column && current_direction == "asc") ? "desc" : "asc"
    new_query = query.merge("sort" => column, "direction" => next_direction).except("page")

    content = label.dup
    content << (current_direction == "asc" ? " ▲" : " ▼") if current_column == column

    link_to content, "#{request.path}?#{new_query.to_query}", class: "inline-flex items-center gap-1 hover:text-gray-900"
  end

  # Incoming mail is shown via IncomingMailsController#show, not DocumentsController#show,
  # even when it appears merged into the outgoing ToDo/Waiting/Info tables.
  def document_row_path(document)
    if document.incoming?
      entity_incoming_mail_path(current_entity, document)
    else
      entity_document_path(current_entity, document)
    end
  end
end
