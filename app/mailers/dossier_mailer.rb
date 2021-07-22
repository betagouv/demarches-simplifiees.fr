# Preview all emails at http://localhost:3000/rails/mailers/dossier_mailer
class DossierMailer < ApplicationMailer
  helper ServiceHelper
  helper MailerHelper
  helper ProcedureHelper

  layout 'mailers/layout'

  def notify_new_draft(dossier)
    @dossier = dossier
    @service = dossier.procedure.service
    @logo_url = attach_logo(dossier.procedure)

    subject = "Retrouvez votre brouillon pour la démarche « #{dossier.procedure.libelle} »"

    mail(from: NO_REPLY_EMAIL, to: dossier.user_email_for(:notification), subject: subject) do |format|
      format.html { render layout: 'mailers/notifications_layout' }
    end
  end

  def notify_new_answer(dossier, body = nil)
    @dossier = dossier
    @service = dossier.procedure.service
    @logo_url = attach_logo(dossier.procedure)
    @body = body

    subject = "Nouveau message pour votre dossier nº #{dossier.id} (#{dossier.procedure.libelle})"

    mail(from: NO_REPLY_EMAIL, to: dossier.user_email_for(:notification), subject: subject) do |format|
      format.html { render layout: 'mailers/notifications_layout' }
    end
  end

  def notify_new_commentaire_to_instructeur(dossier, instructeur_email)
    @dossier = dossier
    @subject = default_i18n_subject(dossier_id: dossier.id, libelle_demarche: dossier.procedure.libelle)
    mail(from: NO_REPLY_EMAIL, to: instructeur_email, subject: @subject)
  end

  def notify_new_dossier_depose_to_instructeur(dossier, instructeur_email)
    @dossier = dossier
    @subject = default_i18n_subject(dossier_id: dossier.id, libelle_demarche: dossier.procedure.libelle)
    mail(from: NO_REPLY_EMAIL, to: instructeur_email, subject: @subject)
  end

  def notify_revert_to_instruction(dossier)
    @dossier = dossier
    @service = dossier.procedure.service
    @logo_url = attach_logo(dossier.procedure)

    subject = "Votre dossier nº #{@dossier.id} est en train d’être réexaminé"

    mail(from: NO_REPLY_EMAIL, to: dossier.user_email_for(:notification), subject: subject) do |format|
      format.html { render layout: 'mailers/notifications_layout' }
    end
  end

  def notify_brouillon_near_deletion(dossiers, to_email)
    @subject = default_i18n_subject(count: dossiers.count)
    @dossiers = dossiers

    mail(to: to_email, subject: @subject)
  end

  def notify_brouillon_deletion(dossier_hashes, to_email)
    @subject = default_i18n_subject(count: dossier_hashes.count)
    @dossier_hashes = dossier_hashes

    mail(to: to_email, subject: @subject)
  end

  def notify_deletion_to_user(deleted_dossier, to_email)
    @subject = default_i18n_subject(dossier_id: deleted_dossier.dossier_id)
    @deleted_dossier = deleted_dossier

    mail(to: to_email, subject: @subject)
  end

  def notify_instructeur_deletion_to_user(deleted_dossier, to_email)
    @subject = default_i18n_subject(libelle_demarche: deleted_dossier.procedure.libelle)
    @deleted_dossier = deleted_dossier

    mail(to: to_email, subject: @subject)
  end

  def notify_instructeur(deleted_dossier, to_email)
    @subject = default_i18n_subject(dossier_id: deleted_dossier.dossier_id)
    @deleted_dossier = deleted_dossier

    mail(to: to_email, subject: @subject)
  end

  def notify_deletion_to_administration(deleted_dossier, to_email)
    @subject = default_i18n_subject(dossier_id: deleted_dossier.dossier_id)
    @deleted_dossier = deleted_dossier

    mail(to: to_email, subject: @subject)
  end

  def notify_automatic_deletion_to_user(deleted_dossiers, to_email)
    @state = deleted_dossiers.first.state
    @subject = default_i18n_subject(count: deleted_dossiers.count)
    @deleted_dossiers = deleted_dossiers

    mail(to: to_email, subject: @subject)
  end

  def notify_automatic_deletion_to_administration(deleted_dossiers, to_email)
    @subject = default_i18n_subject(count: deleted_dossiers.count)
    @deleted_dossiers = deleted_dossiers

    mail(to: to_email, subject: @subject)
  end

  def notify_near_deletion_to_user(dossiers, to_email)
    @state = dossiers.first.state
    @subject = default_i18n_subject(count: dossiers.count, state: @state)
    @dossiers = dossiers

    mail(to: to_email, subject: @subject)
  end

  def notify_near_deletion_to_administration(dossiers, to_email)
    @state = dossiers.first.state
    @subject = default_i18n_subject(count: dossiers.count, state: @state)
    @dossiers = dossiers

    mail(to: to_email, subject: @subject)
  end

  def notify_groupe_instructeur_changed(instructeur, dossier)
    @subject = "Un dossier a changé de groupe instructeur"
    @dossier_id = dossier.id
    @demarche = dossier.procedure.libelle

    mail(from: NO_REPLY_EMAIL, to: instructeur.email, subject: @subject)
  end

  def notify_brouillon_not_submitted(dossier)
    @subject = "Attention : votre dossier n’est pas déposé."
    @dossier = dossier

    mail(to: dossier.user_email_for(:notification), subject: @subject)
  end

  protected

  # This is an override of `default_i18n_subject` method
  # https://api.rubyonrails.org/v5.0.0/classes/ActionMailer/Base.html#method-i-default_i18n_subject
  def default_i18n_subject(interpolations = {})
    if interpolations[:state]
      mailer_scope = self.class.mailer_name.tr('/', '.')
      state = interpolations[:state].in?(Dossier::TERMINE) ? 'termine' : interpolations[:state]
      I18n.t("subject_#{state}", **interpolations.merge(scope: [mailer_scope, action_name]))
    else
      super
    end
  end
end
