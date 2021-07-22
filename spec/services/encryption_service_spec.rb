describe EncryptionService do
  describe "#encrypt" do
    subject { EncryptionService.new.encrypt(value) }

    context "with a nil value" do
      let(:value) { nil }

      it { expect(subject).to be_nil }
    end

    context "with a string value" do
      let(:value) { "The quick brown fox jumps over the lazy dog" }

      it { expect(subject).to be_instance_of(String) }
      it { expect(subject).to be_present }
      it { expect(subject).not_to eq(value) }
    end
  end

  describe "#decrypt" do
    subject { EncryptionService.new.decrypt(encrypted_value) }

    context "with a nil value" do
      let(:encrypted_value) { nil }

      it { expect(subject).to be_nil }
    end

    context "with a string value" do
      let (:value) { "The quick brown fox jumps over the lazy dog" }
      let(:encrypted_value) { EncryptionService.new.encrypt(value) }

      it { expect(subject).to eq(value) }
    end

    context "with an invalid value" do
      let(:encrypted_value) { "Gur dhvpx oebja sbk whzcf bire gur ynml qbt" }

      it { expect { subject }.to raise_exception StandardError }
    end
  end
end
