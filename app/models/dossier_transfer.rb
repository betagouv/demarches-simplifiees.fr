# == Schema Information
#
# Table name: dossier_transfers
#
#  id         :bigint           not null, primary key
#  email      :string           not null
#  token      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class DossierTransfer < ApplicationRecord
  has_secure_token
  has_many :dossiers, dependent: :nullify

  EXPIRATION_LIMIT = 2.days

  scope :not_expired, -> { where('created_at > ?', (Time.zone.now - EXPIRATION_LIMIT)) }
  scope :expired, -> { where('created_at < ?', (Time.zone.now - EXPIRATION_LIMIT)) }

  after_create_commit :send_notification

  def self.initiate(email, dossiers)
    create(email: email, dossiers: dossiers)
  end

  def self.finalize(token, current_user)
    transfer = not_expired.find_by(token: token, email: current_user.email)

    if transfer && transfer.dossiers.present?
      transfer
        .dossiers
        .update_all(user_id: current_user.id)
      Invite
        .where(email_sender: dossier.user.email, dossier: transfer.dossiers)
        .update_all(email_sender: transfer.email)
      DossierTransferLog.create(transfer.dossiers.map { |dossier|  { dossier: dossier, from: dossier.user.email, to: transfer.email } })
      transfer.destroy
      true
    else
      false
    end
  end

  private

  def send_notification
    DossierMailer.notify_transfer(self).deliver_later
  end
end
