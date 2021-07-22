module EncryptableConcern
  extend ActiveSupport::Concern

  class_methods do
    def attr_encrypted(*attributes)
      attributes.each do |attribute|
        define_method("#{attribute}=".to_sym) do |value|
          self.public_send(
            "encrypted_#{attribute}=".to_sym,
            EncryptionService.new.encrypt(value)
          )
        end

        define_method(attribute) do
          value = self.public_send("encrypted_#{attribute}".to_sym)
          EncryptionService.new.decrypt(value) if value.present?
        end
      end
    end
  end
end
