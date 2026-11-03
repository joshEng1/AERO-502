namespace :sprint3 do
     desc "Read-only check of legacy memberships and task history before Sprint 3 migration"
     task preflight: :environment do
          require Rails.root.join("lib/sprint_three/legacy_data")
          if ActiveRecord::Base.connection.table_exists?(:team_memberships)
               review = SprintThree::LegacyData.new(ActiveRecord::Base.connection)
               puts JSON.pretty_generate(review.report)
               abort "Reconcile the listed records before migrating." if review.errors.any?
          else
               puts "The legacy membership tables are absent; use db:migrate:status to identify this schema."
          end
     end
end
