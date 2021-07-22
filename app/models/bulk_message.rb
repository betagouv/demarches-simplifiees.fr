# == Schema Information
#
# Table name: bulk_messages
#
#  id             :bigint           not null, primary key
#  body           :text             not null
#  dossier_count  :integer
#  dossier_state  :string
#  sent_at        :datetime         not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  instructeur_id :bigint           not null
#
class BulkMessage < ApplicationRecord
  belongs_to :instructeur
  has_one_attached :piece_jointe
  has_and_belongs_to_many :groupe_instructeurs
end
