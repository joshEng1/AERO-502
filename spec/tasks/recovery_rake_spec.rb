require "rails_helper"
require "rake"

RSpec.describe "Read-only deployment verification commands" do
     self.use_transactional_tests = false

     before(:all) { Rails.application.load_tasks if Rake::Task.tasks.empty? }

     it "captures a consistent recovery manifest without changing records" do
          before = RecoveryManifest.capture(ApplicationRecord.connection)
          Rake::Task["recovery:manifest"].reenable
          expect { Rake::Task["recovery:manifest"].invoke }.to output(/"tables"/).to_stdout
          expect(RecoveryManifest.capture(ApplicationRecord.connection)).to eq(before)
     end

     it "identifies an already migrated schema without attempting legacy conversion" do
          Rake::Task["sprint3:preflight"].reenable
          expect { Rake::Task["sprint3:preflight"].invoke }.to output(/legacy membership tables are absent/).to_stdout
          person = User.new(name: "Validation only", email: "validation-only@tamu.edu", role: :chief_engineer)
          expect(person).to be_valid
          expect(person).to be_new_record
     end
end
