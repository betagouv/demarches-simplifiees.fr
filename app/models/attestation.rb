class Attestation < ApplicationRecord
  self.ignored_columns = ['pdf']

  belongs_to :dossier

  has_one_attached :pdf
  has_one_attached :pdf_active_storage

  scope :for_dossier, -> (dossier_id) { where(dossier_id: dossier_id) }

  def pdf_url
    if pdf.attached?
      Rails.application.routes.url_helpers.url_for(pdf)
    elsif pdf_active_storage.attached?
      Rails.application.routes.url_helpers.url_for(pdf_active_storage)
    end
  end
end
