# frozen_string_literal: true

module Templates
  module Actions
    class CreateCcRecipients < ApplicationAction
      expects :document, :cc_party_tokens

      executed do |ctx|
        (ctx.cc_party_tokens || []).reject(&:blank?).each do |token|
          cc_recipient = ctx.document.cc_recipients.new(party_token: token)
          next if cc_recipient.save

          fail_with!(ctx, cc_recipient.errors.full_messages.to_sentence, :validation_error)
          break
        end
      end
    end
  end
end
