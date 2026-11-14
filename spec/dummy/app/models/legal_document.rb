class LegalDocument < ActiveRecord::Base
  include DocumensoRails::Model

  has_one_attached :unsigned_pdf
  has_one_attached :signed_pdf
end
