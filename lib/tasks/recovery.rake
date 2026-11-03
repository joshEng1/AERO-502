namespace :recovery do
     desc "Print a read-only database recovery verification manifest (counts and checksums, no record values)"
     task manifest: :environment do
          result = ApplicationRecord.transaction(isolation: :repeatable_read) do
               ApplicationRecord.connection.execute("SET TRANSACTION READ ONLY")
               RecoveryManifest.capture(ApplicationRecord.connection)
          end
          puts JSON.pretty_generate(result)
     end
end
