class NormalizeUserMembershipIdentity < ActiveRecord::Migration[8.1]
     def up
          # Class roles and membership live on their relationships; only the
          # organization-wide Chief Engineer role remains on the identity record.
          rename_column :users, :role, :global_role
          execute "UPDATE users SET global_role = 0 WHERE global_role = 1"
          remove_reference :users, :subteam, foreign_key: true
          remove_reference :users, :team, foreign_key: true
     end

     def down
          raise ActiveRecord::IrreversibleMigration, "Restore the pre-update backup to recover legacy primary membership columns."
     end
end
