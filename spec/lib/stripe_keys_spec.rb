require "rails_helper"

RSpec.describe StripeKeys do
  describe ".test_key?" do
    [ "sk_test_51AbcDEF123", "rk_test_51AbcDEF123", "rkcs_test_51AbcDEF123" ].each do |key|
      it "aceita a chave de teste #{key[0, 8]}..." do
        expect(described_class.test_key?(key)).to be(true)
      end
    end

    [ "sk_live_51AbcDEF123", "rk_live_51AbcDEF123", "rkcs_live_51AbcDEF123", "pk_test_51AbcDEF123",
      "sk_test_", "", nil,
      " sk_test_51Abc", "sk_test_51Abc\nsk_live_x" ].each do |key|
      it "recusa #{key.inspect}" do
        expect(described_class.test_key?(key)).to be(false)
      end
    end
  end

  describe ".webhook_secret?" do
    it "aceita whsec_ seguido de letras e números" do
      expect(described_class.webhook_secret?("whsec_1a2B3c")).to be(true)
    end

    it "recusa o resto" do
      expect(described_class.webhook_secret?("sk_test_123")).to be(false)
      expect(described_class.webhook_secret?("whsec_")).to be(false)
      expect(described_class.webhook_secret?(nil)).to be(false)
    end
  end
end
