module DocumensoRails
  class Configuration
    attr_accessor :base_url,
                  :api_key,
                  :webhook_secret,
                  :model_class_name,
                  :unsigned_attachment_name,
                  :signed_attachment_name,
                  :redirect_url

    def initialize
      @base_url                 = ENV.fetch("DOCUMENSO_API_URL", "https://app.documenso.com/api/v2")
      @api_key                  = nil
      @webhook_secret           = nil
      @model_class_name         = "LegalDocument"
      @unsigned_attachment_name = :unsigned_pdf
      @signed_attachment_name   = :signed_pdf
      @redirect_url             = nil
    end

    def model_class
      @model_class_name.constantize
    end
  end
end
