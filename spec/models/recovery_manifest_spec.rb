require "rails_helper"

RSpec.describe RecoveryManifest do
     it "compares all ten tables without exposing account values and detects changed data" do
          baseline = described_class.capture(ApplicationRecord.connection)
          expect(baseline[:tables].keys.size).to eq(10)
          expect(baseline[:tables]["tasks"][:count]).to eq(2)
          expect(baseline[:total_actual_hours]).to eq("4.0")
          expect(baseline.to_json).not_to include(users(:member).email, users(:member).password_digest)
          expect(described_class.capture(ApplicationRecord.connection)).to eq(baseline)
          tasks(:wing_test).update!(title: "Changed after backup")
          after = described_class.capture(ApplicationRecord.connection)
          expect(after[:tables]["tasks"][:sha256]).not_to eq(baseline[:tables]["tasks"][:sha256])
          expect(after[:tables]["time_entries"]).to eq(baseline[:tables]["time_entries"])
     end
end
