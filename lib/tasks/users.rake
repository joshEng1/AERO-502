namespace :users do
     desc "Give Google sign-in emails Chief Engineer access. " \
          "Usage: bin/rails users:grant_chief_engineer EMAILS=\"a@tamu.edu,b@tamu.edu\""
     task grant_chief_engineer: :environment do
          emails = ENV.fetch("EMAILS", "").split(",").map { |email| email.strip.downcase }.compact_blank.uniq
          abort "Set EMAILS to a comma-separated list of Google (TAMU) emails." if emails.empty?

          failed = emails.reject do |email|
               user = User.find_or_initialize_by(email: email)
               # Google sign-in does not set names; use the email's first part until they edit it.
               user.name = email.split("@").first if user.name.blank?
               user.role = :chief_engineer
               user.subteam = nil
               user.access_revoked_at = nil

               if user.save
                    puts "#{email}: Chief Engineer (#{user.previously_new_record? ? 'added' : 'updated'})"
                    true
               else
                    warn "#{email}: #{user.errors.full_messages.to_sentence}"
                    false
               end
          end

          abort "Could not grant access to: #{failed.join(', ')}" if failed.any?
     end
end
