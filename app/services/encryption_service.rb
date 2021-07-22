class EncryptionService
  def initialize
    len        = ActiveSupport::MessageEncryptor.key_len
    salt       = Rails.application.secrets.encryption_service_salt
    password   = Rails.application.secrets.secret_key_base
    key        = ActiveSupport::KeyGenerator.new(password).generate_key(salt, len)
    @encryptor = ActiveSupport::MessageEncryptor.new(key)
  end

  def encrypt(value)
    value.blank? ? nil : @encryptor.encrypt_and_sign(value)
  end

  def decrypt(value)
    value.blank? ? nil : @encryptor.decrypt_and_verify(value)
  end
end
