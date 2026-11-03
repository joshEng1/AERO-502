require "rails_helper"

RSpec.describe TaskStatusChange, type: :model do
     it "requires a real actor and status instead of a placeholder history record" do
          change = TaskStatusChange.new(task: tasks(:wing_test), to_status: :in_progress, created_at: Time.current)
          expect(change).not_to be_valid
          expect(change.errors[:actor]).to be_present
     end

     it "retains immutable status history" do
          change = task_status_changes(:wing_initial)
          expect { change.update!(to_status: :completed) }.to raise_error(ActiveRecord::ReadOnlyRecord)
     end
end
