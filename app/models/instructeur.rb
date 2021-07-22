# == Schema Information
#
# Table name: instructeurs
#
#  id                       :integer          not null, primary key
#  bypass_email_login_token :boolean          default(FALSE), not null
#  encrypted_login_token    :text
#  login_token_created_at   :datetime
#  created_at               :datetime
#  updated_at               :datetime
#
class Instructeur < ApplicationRecord
  has_and_belongs_to_many :administrateurs

  has_many :assign_to, dependent: :destroy
  has_many :groupe_instructeurs, through: :assign_to
  has_many :procedures, -> { distinct }, through: :groupe_instructeurs

  has_many :assign_to_with_email_notifications, -> { with_email_notifications }, class_name: 'AssignTo', inverse_of: :instructeur
  has_many :groupe_instructeur_with_email_notifications, through: :assign_to_with_email_notifications, source: :groupe_instructeur

  has_many :dossiers, -> { state_not_brouillon }, through: :groupe_instructeurs
  has_many :follows, -> { active }, inverse_of: :instructeur
  has_many :previous_follows, -> { inactive }, class_name: 'Follow', inverse_of: :instructeur
  has_many :followed_dossiers, through: :follows, source: :dossier
  has_many :previously_followed_dossiers, -> { distinct }, through: :previous_follows, source: :dossier
  has_many :trusted_device_tokens, dependent: :destroy
  has_many :archives
  has_many :bulk_messages, dependent: :destroy

  has_one :user, dependent: :nullify

  scope :with_instant_email_message_notifications, -> {
    includes(:assign_to).where(assign_tos: { instant_email_message_notifications_enabled: true })
  }

  scope :with_instant_email_dossier_notifications, -> {
    includes(:assign_to).where(assign_tos: { instant_email_dossier_notifications_enabled: true })
  }

  default_scope { eager_load(:user) }

  def self.by_email(email)
    Instructeur.eager_load(:user).find_by(users: { email: email })
  end

  def email
    user.email
  end

  def follow(dossier)
    begin
      followed_dossiers << dossier
      # If the user tries to follow a dossier she already follows,
      # we just fail silently: it means the goal is already reached.
    rescue ActiveRecord::RecordNotUnique
      # Database uniqueness constraint
    rescue ActiveRecord::RecordInvalid => e
      # ActiveRecord validation
      raise unless e.record.errors.details.dig(:instructeur_id, 0, :error) == :taken
    end
  end

  def unfollow(dossier)
    f = follows.find_by(dossier: dossier)
    if f.present?
      f.update(unfollowed_at: Time.zone.now)
    end
  end

  def follow?(dossier)
    followed_dossiers.include?(dossier)
  end

  def assign_to_procedure(procedure)
    begin
      assign_to.create({
        procedure: procedure,
        groupe_instructeur: procedure.defaut_groupe_instructeur
      })
      true
    rescue ActiveRecord::RecordNotUnique
      false
    end
  end

  def remove_from_procedure(procedure)
    !!(procedure.defaut_groupe_instructeur.in?(groupe_instructeurs) && groupe_instructeurs.destroy(procedure.defaut_groupe_instructeur))
  end

  def last_week_overview
    start_date = Time.zone.now.beginning_of_week

    active_procedure_overviews = procedures
      .where(assign_tos: { weekly_email_notifications_enabled: true })
      .publiees
      .map { |procedure| procedure.procedure_overview(start_date, groupe_instructeurs) }
      .filter(&:had_some_activities?)

    if active_procedure_overviews.empty?
      nil
    else
      {
        start_date: start_date,
        procedure_overviews: active_procedure_overviews
      }
    end
  end

  def procedure_presentation_and_errors_for_procedure_id(procedure_id)
    assign_to.joins(:groupe_instructeur).find_by(groupe_instructeurs: { procedure_id: procedure_id }).procedure_presentation_or_default_and_errors
  end

  def notifications_for_dossier(dossier)
    follow = Follow
      .includes(dossier: [:champs, :avis, :commentaires])
      .find_by(instructeur: self, dossier: dossier)

    if follow.present?
      demande = follow.dossier.champs.updated_since?(follow.demande_seen_at).any? || follow.dossier.groupe_instructeur_updated_at&.>(follow.demande_seen_at)
      demande = false if demande.nil?

      annotations_privees = follow.dossier.champs_private.updated_since?(follow.annotations_privees_seen_at).any?

      avis_notif = follow.dossier.avis.updated_since?(follow.avis_seen_at).any?

      messagerie = dossier.commentaires
        .where.not(email: OLD_CONTACT_EMAIL)
        .where.not(email: CONTACT_EMAIL)
        .updated_since?(follow.messagerie_seen_at).any?

      annotations_hash(demande, annotations_privees, avis_notif, messagerie)
    else
      annotations_hash(false, false, false, false)
    end
  end

  def notifications_for_groupe_instructeurs(groupe_instructeurs)
    Dossier
      .not_archived
      .where(groupe_instructeur: groupe_instructeurs)
      .merge(followed_dossiers)
      .with_notifications
      .pluck(:state, :id)
      .reduce({ termines: [], en_cours: [] }) do |acc, e|
        if Dossier::TERMINE.include?(e[0])
          acc[:termines] << e[1]
        elsif Dossier::EN_CONSTRUCTION_OU_INSTRUCTION.include?(e[0])
          acc[:en_cours] << e[1]
        end
        acc
      end
  end

  def procedure_ids_with_notifications(scope)
    groupe_instructeur_ids = Dossier
      .send(scope) # :en_cours or :termine (or any other Dossier scope)
      .merge(followed_dossiers)
      .with_notifications
      .select(:groupe_instructeur_id)

    GroupeInstructeur.where(id: groupe_instructeur_ids).pluck(:procedure_id)
  end

  def mark_tab_as_seen(dossier, tab)
    attributes = {}
    attributes["#{tab}_seen_at"] = Time.zone.now
    Follow.where(instructeur: self, dossier: dossier).update_all(attributes)
  end

  def email_notification_data
    groupe_instructeur_with_email_notifications
      .reduce([]) do |acc, groupe|
      procedure = groupe.procedure

      notifications = notifications_for_groupe_instructeurs([groupe.id])
      nb_notification = notifications[:en_cours].count + notifications[:termines].count

      h = {
        nb_en_construction: groupe.dossiers.en_construction.count,
        nb_en_instruction: groupe.dossiers.en_instruction.count,
        nb_accepted: Traitement.where(dossier: groupe.dossiers.accepte, processed_at: Time.zone.yesterday.beginning_of_day..Time.zone.yesterday.end_of_day).count,
        nb_notification: nb_notification
      }

      if h[:nb_en_construction] > 0 || h[:nb_notification] > 0
        h[:procedure_id] = procedure.id
        h[:procedure_libelle] = procedure.libelle
        acc << h
      end

      if h[:nb_en_instruction] > 0 || h[:nb_accepted] > 0
        [["en_instruction", h[:nb_en_instruction]], ["accepte", h[:nb_accepted]]].each do |state, count|
          if procedure&.declarative_with_state == state && count > 0
            h[:procedure_id] = procedure.id
            h[:procedure_libelle] = procedure.libelle
            acc << h
          end
        end
      end

      acc
    end
  end

  def create_trusted_device_token
    trusted_device_token = trusted_device_tokens.create
    trusted_device_token.token
  end

  def young_login_token?
    trusted_device_token = trusted_device_tokens.order(created_at: :desc).first
    trusted_device_token&.token_young?
  end

  def can_be_deleted?
    user.administrateur.nil? && procedures.all? { |p| p.defaut_groupe_instructeur.instructeurs.count > 1 }
  end

  # required to display feature flags field in manager
  def features
  end

  def flipper_id
    "Instructeur:#{id}"
  end

  def dossiers_count_summary(groupe_instructeur_ids)
    query = <<~EOF
      SELECT
        COUNT(DISTINCT dossiers.id) FILTER (where not archived AND dossiers.state in ('en_construction', 'en_instruction') AND follows.id IS NULL) AS a_suivre,
        COUNT(DISTINCT dossiers.id) FILTER (where not archived AND dossiers.state in ('en_construction', 'en_instruction') AND follows.instructeur_id = :instructeur_id) AS suivis,
        COUNT(DISTINCT dossiers.id) FILTER (where not archived AND dossiers.state in ('accepte', 'refuse', 'sans_suite')) AS traites,
        COUNT(DISTINCT dossiers.id) FILTER (where not archived) AS tous,
        COUNT(DISTINCT dossiers.id) FILTER (where archived)     AS archives
      FROM "dossiers"
        LEFT OUTER JOIN follows
          ON  follows.dossier_id = dossiers.id
          AND follows.unfollowed_at IS NULL
      WHERE "dossiers"."hidden_at" IS NULL
        AND "dossiers"."state" != 'brouillon'
        AND "dossiers"."groupe_instructeur_id" in (:groupe_instructeur_ids)
    EOF

    sanitized_query = ActiveRecord::Base.sanitize_sql([
      query,
      instructeur_id: id,
      groupe_instructeur_ids: groupe_instructeur_ids
    ])

    Dossier.connection.select_all(sanitized_query).first
  end

  private

  def annotations_hash(demande, annotations_privees, avis, messagerie)
    {
      demande: demande,
      annotations_privees: annotations_privees,
      avis: avis,
      messagerie: messagerie
    }
  end
end
