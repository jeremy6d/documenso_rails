module DocumensoRails
  class WebhooksController < ActionController::API
    before_action :verify_secret!

    def create
      event       = params[:event].to_s
      payload     = params[:payload]&.to_unsafe_h || {}
      envelope_id = payload["envelopeId"]

      if event.present? && envelope_id.present?
        ProcessWebhookJob.perform_later(event, envelope_id, payload)
      end

      head :ok
    end

    private

    def verify_secret!
      expected = DocumensoRails.configuration.webhook_secret.to_s
      provided = request.headers["X-Documenso-Secret"].to_s

      if expected.blank? || !ActiveSupport::SecurityUtils.secure_compare(expected, provided)
        head :unauthorized
      end
    end
  end
end
