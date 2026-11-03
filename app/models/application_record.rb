class ApplicationRecord < ActiveRecord::Base
     primary_abstract_class
     before_validation :lock_shared_integrity

     private

     def lock_shared_integrity
          self.class.connection.execute("SELECT pg_advisory_xact_lock(5023001)") if self.class.connection.transaction_open?
     end
end
