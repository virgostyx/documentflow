# frozen_string_literal: true

module Wopi
  # WOPI host endpoints consumed by Collabora Online, not by browsers. Calls
  # arrive server-to-server carrying a Wopi::AccessToken instead of a Devise
  # session, so authentication and CSRF protection are handled differently
  # from the rest of the app. Locking/versioning is delegated to the same
  # organizers the manual check-out/check-in UI uses (Documents::CheckOutOrganizer,
  # Documents::CheckInOrganizer, Documents::CancelCheckOutOrganizer) so both
  # flows stay consistent.
  class FilesController < ApplicationController
    skip_before_action :authenticate_user!
    skip_before_action :verify_authenticity_token, raise: false

    before_action :authenticate_wopi_request!

    def check_file_info
      return render_wopi_error(:forbidden) unless authorized_for_document?
      return head :not_found unless @document.main_file.attached?

      render json: {
        BaseFileName: @document.main_file.filename.to_s,
        Size: @document.main_file.byte_size,
        OwnerId: (@document.checked_out_by_id || @document.created_by_id).to_s,
        UserId: @wopi_user.id.to_s,
        UserFriendlyName: @wopi_user.full_name,
        Version: @document.main_file.blob.checksum,
        UserCanWrite: can_write?,
        SupportsLocks: true,
        SupportsUpdate: true,
        IsAdminUser: false
      }
    end

    def get_file
      return render_wopi_error(:forbidden) unless authorized_for_document?
      return head :not_found unless @document.main_file.attached?

      send_data @document.main_file.download,
                filename: @document.main_file.filename.to_s,
                type: @document.main_file.content_type,
                disposition: "attachment"
    end

    def put_file
      return render_wopi_error(:forbidden) unless policy.check_in?
      return render_lock_conflict unless lock_matches?

      result = Documents::CheckInOrganizer.call(
        document: @document,
        current_user: @wopi_user,
        main_file: uploaded_body,
        annex_files: {},
        comment: "Edited via Collabora Online",
        skip_release: true
      )

      result.success? ? head(:ok) : render_wopi_error(:internal_server_error)
    end

    def lock_dispatch
      case request.headers["X-WOPI-Override"]
      when "LOCK" then handle_lock
      when "REFRESH_LOCK" then handle_refresh_lock
      when "UNLOCK" then handle_unlock
      else render_wopi_error(:not_implemented)
      end
    end

    private

    # Whether this user is permitted to interact with the document's file at
    # all (same underlying rule as DocumentPolicy#update?), independent of
    # who currently holds the WOPI lock. Distinguishing this from can_write?
    # lets a lock conflict be reported as 409, not a blanket 403.
    def authorized_for_document?
      policy.update?
    end

    def can_write?
      policy.check_out? || policy.check_in?
    end

    def policy
      @policy ||= DocumentPolicy.new(@wopi_user, @document)
    end

    def authenticate_wopi_request!
      payload = Wopi::AccessToken.decode(params[:access_token])
      return render_wopi_error(:unauthorized) if payload.nil?

      @document = Document.find_by(id: payload.document_id)
      @wopi_user = User.find_by(id: payload.user_id)
      render_wopi_error(:unauthorized) if @document.nil? || @wopi_user.nil?
    end

    def requested_lock
      request.headers["X-WOPI-Lock"]
    end

    def lock_matches?
      @document.wopi_lock_id.present? && @document.wopi_lock_id == requested_lock
    end

    def handle_lock
      return render_wopi_error(:forbidden) unless authorized_for_document?

      if @document.checked_out_by?(@wopi_user)
        @document.update!(wopi_lock_id: requested_lock)
        return head :ok
      end

      return render_lock_conflict if @document.checked_out?

      result = Documents::CheckOutOrganizer.call(document: @document, current_user: @wopi_user)
      return render_lock_conflict unless result.success?

      @document.update!(wopi_lock_id: requested_lock)
      head :ok
    end

    def handle_refresh_lock
      return render_wopi_error(:forbidden) unless policy.check_in?
      return render_lock_conflict unless lock_matches?

      @document.touch(:checked_out_at)
      head :ok
    end

    def handle_unlock
      return render_wopi_error(:forbidden) unless policy.check_in?
      return render_lock_conflict unless lock_matches?

      Documents::CancelCheckOutOrganizer.call(document: @document, current_user: @wopi_user)
      head :ok
    end

    def render_lock_conflict
      response.headers["X-WOPI-Lock"] = @document.wopi_lock_id.to_s
      render_wopi_error(:conflict)
    end

    def render_wopi_error(status)
      head status
    end

    # Collabora saves in the same format the document was opened in, so the
    # filename/content-type of the currently attached main_file still apply.
    def uploaded_body
      {
        io: StringIO.new(request.body.read),
        filename: @document.main_file.filename.to_s,
        content_type: @document.main_file.content_type
      }
    end
  end
end
