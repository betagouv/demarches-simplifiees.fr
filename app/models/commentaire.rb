# == Schema Information
#
# Table name: commentaires
#
#  id             :integer          not null, primary key
#  body           :string
#  email          :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  dossier_id     :integer
#  expert_id      :bigint
#  instructeur_id :bigint
#
class Commentaire < ApplicationRecord
  self.ignored_columns = [:user_id]
  belongs_to :dossier, inverse_of: :commentaires, touch: true, optional: false

  belongs_to :instructeur, optional: true
  belongs_to :expert, optional: true

  validate :messagerie_available?, on: :create, unless: -> { dossier.brouillon? }

  has_one_attached :piece_jointe

  validates :body, presence: { message: "ne peut être vide" }

  validates :piece_jointe,
    content_type: AUTHORIZED_CONTENT_TYPES,
    size: { less_than: 20.megabytes }

  default_scope { order(created_at: :asc) }
  scope :updated_since?, -> (date) { where('commentaires.updated_at > ?', date) }

  after_create :notify

  def email
    if sent_by_instructeur?
      instructeur.email
    elsif sent_by_expert?
      expert.email
    else
      read_attribute(:email)
    end
  end

  def header
    "#{redacted_email}, #{I18n.l(created_at, format: '%d %b %Y %H:%M')}"
  end

  def redacted_email
    if sent_by_instructeur?
      if Flipper.enabled?(:hide_instructeur_email, dossier.procedure)
        "Instructeur n° #{instructeur.id}"
      else
        instructeur.email.split('@').first
      end
    else
      email
    end
  end

  def sent_by_system?
    [CONTACT_EMAIL, OLD_CONTACT_EMAIL].include?(email)
  end

  def sent_by_instructeur?
    instructeur_id.present?
  end

  def sent_by_expert?
    expert_id.present?
  end

  def sent_by?(someone)
    email == someone.email
  end

  def file_url
    if piece_jointe.attached? && piece_jointe.virus_scanner.safe?
      Rails.application.routes.url_helpers.url_for(piece_jointe)
    end
  end

  private

  def notify
    # - If the email is the contact email, the commentaire is a copy
    #   of an automated notification email we sent to a user, so do nothing.
    # - If a user or an invited user posted a commentaire, do nothing,
    #   the notification system will properly
    # - Otherwise, a instructeur posted a commentaire, we need to notify the user
    if sent_by_instructeur? || sent_by_expert?
      notify_user
    end
  end

  def notify_user
    DossierMailer.notify_new_answer(dossier, body).deliver_later
  end

  def messagerie_available?
    return if sent_by_system?
    if dossier.present? && !dossier.messagerie_available?
      errors.add(:dossier, "Il n’est pas possible d’envoyer un message sur un dossier archivé ou en brouillon")
    end
  end
end
