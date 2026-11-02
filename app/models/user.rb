class User < ApplicationRecord
     has_secure_password validations: false
     enum :role, { member: 0, officer: 1, chief_engineer: 2 }, validate: true
     has_one :membership, inverse_of: :user, autosave: true, dependent: :destroy
     has_one :subteam, through: :membership
     has_one :team, through: :subteam
     has_many :task_assignments, dependent: :restrict_with_error
     has_many :active_assignments, -> { active }, class_name: "TaskAssignment"
     has_many :assigned_tasks, through: :active_assignments, source: :task
     has_many :time_entries, dependent: :restrict_with_error
     has_many :created_tasks, class_name: "Task", foreign_key: :creator_id, inverse_of: :creator, dependent: :restrict_with_error
     has_many :made_assignments, class_name: "TaskAssignment", foreign_key: :assigned_by_id, dependent: :restrict_with_error
     has_many :ended_assignments, class_name: "TaskAssignment", foreign_key: :unassigned_by_id, dependent: :restrict_with_error
     has_many :status_changes, class_name: "TaskStatusChange", foreign_key: :actor_id, dependent: :restrict_with_error

     scope :in_teams, ->(ids) { joins(membership: :subteam).where(subteams: { team_id: ids }) }
     scope :in_subteam, ->(id) { joins(:membership).where(memberships: { subteam_id: id }) }
     scope :assignable, -> { where(role: [ :member, :officer ], access_revoked_at: nil).joins(:membership) }

     ROLE_LABELS = { "member" => "Member", "officer" => "Officer", "chief_engineer" => "Chief Engineer" }.freeze
     ROLES_WITH_ARTICLE = { "member" => "a Member", "officer" => "an Officer", "chief_engineer" => "a Chief Engineer" }.freeze

     before_validation :normalize_email
     validate :preserve_last_active_chief_engineer
     validates :name, presence: true
     validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
     validate :membership_matches_role
     validate :assignments_stay_eligible

     def subteam
          membership&.subteam unless membership&.marked_for_destruction?
     end

     def subteam=(value)
          if value
               (membership || build_membership).subteam = value
          elsif membership&.persisted?
               membership.mark_for_destruction
          else
               self.membership = nil
          end
     end

     def subteam_id
          subteam&.id
     end

     def subteam_id=(value)
          self.subteam = value.present? ? Subteam.find_by(id: value) : nil
     end

     def team
          subteam&.team
     end

     def team_id
          team&.id
     end

     # Existing callers may submit a class as a validation hint; it is not stored.
     def team=(value)
          @requested_team_id = value&.id
     end

     def team_id=(value)
          @requested_team_id = value.presence&.to_i
     end

     def role_label
          ROLE_LABELS.fetch(role)
     end

     def role_with_article
          ROLES_WITH_ARTICLE.fetch(role)
     end

     def access_revoked?
          access_revoked_at.present?
     end

     def authenticate_password_sign_in(password)
          password_digest.present? && authenticate(password)
     end

     def leader?
          officer? || chief_engineer?
     end

     def can_manage?(task)
          !access_revoked? && (chief_engineer? || (officer? && task.team_id == team_id))
     end

     def can_work_on?(task)
          !access_revoked? && task.assignee_ids.include?(id)
     end

     private

     def membership_matches_role
          if chief_engineer?
               errors.add(:subteam, "must be blank for a Chief Engineer") if subteam
          else
               errors.add(:subteam, "is required for a member or officer") unless subteam
               if @requested_team_id && subteam && subteam.team_id != @requested_team_id
                    errors.add(:subteam, "must belong to the person's team")
               end
          end
     end

     def assignments_stay_eligible
          return unless persisted? && task_assignments.active.joins(task: :project).where.not(projects: { team_id: team_id }).exists?

          errors.add(:subteam, "cannot change teams until incompatible active assignments are resolved")
     end

     def preserve_last_active_chief_engineer
          return unless role_in_database == "chief_engineer" && access_revoked_at_in_database.nil?
          return if chief_engineer? && !access_revoked?

          self.class.connection.execute("SELECT pg_advisory_xact_lock(260026)")
          return if self.class.chief_engineer.where(access_revoked_at: nil).where.not(id: id).exists?

          errors.add(:base, "At least one active Chief Engineer is required. Add another Chief Engineer before removing this role or access.")
     end

     def normalize_email
          self.email = email.to_s.strip.downcase
     end
end
