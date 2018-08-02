Flipflop.configure do
  strategy :cookie,
    secure: Rails.env.production?,
    httponly: true
  strategy :active_record
  strategy :user_preference
  strategy :default

  group :champs do
    feature :champ_pj,
      title: "Champ pièce justificative"
    feature :champ_siret,
      title: "Champ SIRET"
    feature :champ_linked_dropdown,
      title: "Champ double menu déroulant"
  end

  feature :web_hook
  feature :test_procedure

  group :production do
    feature :remote_storage,
      default: Rails.env.production? || Rails.env.staging?
    feature :weekly_overview,
      default: Rails.env.production?
  end

  feature :pre_maintenance_mode
  feature :maintenance_mode
end
