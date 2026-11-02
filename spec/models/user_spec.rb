require "rails_helper"

RSpec.describe User, type: :model do
     it "normalizes email before validation" do
          user = User.new(name: "Test Member", email: "  TEST@EXAMPLE.COM ",
                          password: "password", role: :member, subteam: subteams(:wing))

          expect(user.valid?).to be_truthy
          expect(user.email).to eq("test@example.com")
     end

     it "chief engineer may exist without a team" do
          user = users(:chief)

          expect(user.valid?).to be_truthy
          expect(user.leader?).to be_truthy
          expect(user.can_manage?(tasks(:spar_check))).to be_truthy
     end

     it "officer manages only tasks in their team" do
          officer = users(:officer)

          expect(officer.can_manage?(tasks(:wing_test))).to be_truthy
          expect(officer.can_manage?(tasks(:spar_check))).to be_falsey
     end
end
