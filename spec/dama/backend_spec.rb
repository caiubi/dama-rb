RSpec.describe Dama::Backend do
  describe ".for" do
    it "returns a Native backend when JS is not defined" do
      backend = described_class.for
      expect(backend).to be_a(Dama::Backend::Native)
    end

    context "when JS is defined" do
      include_context "with JS mock"

      it "returns a Web backend" do
        backend = described_class.for
        expect(backend).to be_a(Dama::Backend::Web)
      end
    end
  end
end
