# == Schema Information
#
# Table name: dossier_transfer_logs
#
#  id         :bigint           not null, primary key
#  from       :string           not null
#  to         :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  dossier_id :bigint           not null
#
class DossierTransferLog < ApplicationRecord
  belongs_to :dossier
end
