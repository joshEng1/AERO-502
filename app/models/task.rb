class Task < ApplicationRecord
     LINK_FORMAT_MESSAGE = "must each be a full web address starting with http:// or https://".freeze
     REFERENCE_HEADING = "\n\nReference links:\n".freeze
     HistoryEntry = Data.define(:created_at, :sort_key, :actor, :description)

     belongs_to :project
     belongs_to :creator, class_name: "User", inverse_of: :created_tasks
     has_one :team, through: :project
     delegate :team_id, to: :project, allow_nil: true
     has_many :task_assignments, dependent: :restrict_with_error
     has_many :active_assignments, -> { active }, class_name: "TaskAssignment"
     has_many :assignees, through: :active_assignments, source: :user
     has_many :subteams, -> { distinct }, through: :assignees
     has_many :time_entries, dependent: :restrict_with_error
     has_many :status_changes, -> { order(:created_at, :id) }, class_name: "TaskStatusChange", dependent: :restrict_with_error
     has_many :task_dependencies, dependent: :restrict_with_error
     has_many :prerequisites, through: :task_dependencies, source: :prerequisite_task
     has_many :dependent_links, class_name: "TaskDependency", foreign_key: :prerequisite_task_id, dependent: :restrict_with_error

     enum :status, { backlog: 0, in_progress: 1, completed: 2 }, validate: true
     attr_accessor :acting_user, :allowed_team_id
     attribute :start_date, :date, default: -> { Date.current }

     validates :title, :project, :start_date, :due_date, :status, presence: true
     validates :estimated_hours, numericality: { greater_than_or_equal_to: 0 }
     validate :project_in_allowed_team
     validate :project_is_available
     validate :due_date_not_before_start_date
     validate :reference_links_are_web_addresses
     validate :status_actor_is_authorized
     validate :assignments_remain_in_team
     before_save :merge_reference_links
     after_create :record_initial_status
     after_update :record_status_change, if: :saved_change_to_status?

     scope :accessible_to, lambda { |user|
          if user.chief_engineer?
               all
          elsif user.officer?
               joins(:project).where(projects: { team_id: user.team_id })
          else
               where(id: TaskAssignment.active.where(user_id: user.id).select(:task_id))
          end
     }

     scope :in_active_projects, -> {
          joins(project: :team).where(projects: { archived_at: nil }, teams: { archived_at: nil })
     }

     def subteam_names
          subteams.sort_by(&:name).map(&:name).join("; ").presence || "Unassigned"
     end

     def primary_contact
          active_assignments.find_by(is_primary_contact: true)&.user
     end

     def primary_contact_id
          primary_contact&.id
     end

     def instructions_without_reference_links
          instructions.to_s.split(REFERENCE_HEADING, 2).first.to_s
     end

     def reference_links_text
          (@reference_urls || instructions.to_s.split(REFERENCE_HEADING, 2).last.to_s.lines.map(&:strip).select { |line| web_address?(line) }).join("\n")
     end

     def reference_links_text=(text)
          @reference_urls = text.to_s.lines.map(&:strip).compact_blank.uniq
     end

     def reference_urls
          URI.extract(instructions.to_s, %w[http https]).uniq.select { |url| web_address?(url) }
     end

     # Each assignment period is retained. Explicit actor and time are required.
     def assign_members(user_ids, actor:)
          ids = Array(user_ids).reject(&:blank?).map(&:to_i).uniq
          # Revoking access retains existing assignments. Keeping one in an
          # unrelated edit must not silently end its historical period.
          eligible = (User.assignable.in_teams(team_id).where(id: ids).pluck(:id) + active_assignments.where(user_id: ids).pluck(:user_id)).uniq
          unless ids.sort == eligible.sort && actor.can_manage?(self)
               errors.add(:assignees, "must be eligible members of this project's team")
               raise ActiveRecord::RecordInvalid, self
          end
          self.class.transaction do
               self.class.connection.execute("SELECT pg_advisory_xact_lock(5023001)")
               now = Time.current
               active_assignments.where.not(user_id: ids).each do |assignment|
                    assignment.update!(unassigned_by: actor, unassigned_at: now, is_primary_contact: false)
               end
               current_ids = active_assignments.pluck(:user_id)
               (ids - current_ids).each do |id|
                    task_assignments.create!(user_id: id, assigned_by: actor, assigned_at: now)
               end
               association(:active_assignments).reset
               association(:assignees).reset
               association(:subteams).reset
          end
     end

     def designate_primary_contact(user_id)
          id = user_id.presence&.to_i
          if id && !active_assignments.exists?(user_id: id)
               errors.add(:primary_contact, "must be an active assignee")
               raise ActiveRecord::RecordInvalid, self
          end
          self.class.transaction do
               self.class.connection.execute("SELECT pg_advisory_xact_lock(5023001)")
               active_assignments.where(is_primary_contact: true).update_all(is_primary_contact: false)
               active_assignments.find_by!(user_id: id).update!(is_primary_contact: true) if id
          end
     end

     def replace_prerequisites(ids, actor:)
          ids = Array(ids).reject(&:blank?).map(&:to_i).uniq
          candidates = Task.accessible_to(actor).joins(:project).where(projects: { team_id: team_id }, tasks: { id: ids })
          unless actor.can_manage?(self) && candidates.pluck(:id).sort == ids.sort
               errors.add(:prerequisites, "must be tasks you may manage within this team")
               raise ActiveRecord::RecordInvalid, self
          end
          self.class.transaction do
               self.class.connection.execute("SELECT pg_advisory_xact_lock(5023001)")
               task_dependencies.where.not(prerequisite_task_id: ids).delete_all
               (ids - task_dependencies.pluck(:prerequisite_task_id)).each do |id|
                    task_dependencies.create!(prerequisite_task_id: id)
               end
          end
          association(:prerequisites).reset
     end

     def unfinished_prerequisites
          prerequisites.where.not(status: :completed)
     end

     def blocked?
          unfinished_prerequisites.exists?
     end

     def history
          entries = []
          previous = nil
          status_changes.includes(:actor).each do |change|
               description = previous ? "changed the status from #{previous.humanize} to #{change.to_status.humanize}" : "created the task in #{change.to_status.humanize}"
               entries << HistoryEntry.new(change.created_at, [ change.id, 0 ], change.actor, description)
               previous = change.to_status
          end
          task_assignments.includes(:user, :assigned_by, :unassigned_by).each do |assignment|
               entries << HistoryEntry.new(assignment.assigned_at, [ assignment.id, 1 ], assignment.assigned_by, "assigned #{assignment.user.name}")
               if assignment.unassigned_at
                    entries << HistoryEntry.new(assignment.unassigned_at, [ assignment.id, 2 ], assignment.unassigned_by, "removed #{assignment.user.name}")
               end
          end
          entries.sort_by { |entry| [ entry.created_at, entry.sort_key ] }.reverse
     end

     def overdue?
          !completed? && due_date < Date.current
     end

     def total_actual_hours
          time_entries.loaded? ? time_entries.sum(&:hours) : time_entries.sum(:hours)
     end

     def actual_hours_for(user)
          time_entries.loaded? ? time_entries.select { |entry| entry.user_id == user.id }.sum(&:hours) : time_entries.where(user: user).sum(:hours)
     end

     def variance_hours
          total_actual_hours - estimated_hours
     end

     private

     def project_in_allowed_team
          return if allowed_team_id.nil? || team_id == allowed_team_id

          errors.add(:project, "must belong to your team")
     end

     def project_is_available
          return unless project && (new_record? || will_save_change_to_project_id?)
          if project.archived_at || project.team.archived_at
               errors.add(:project, "must be active and belong to an active class")
          end
     end

     def due_date_not_before_start_date
          errors.add(:due_date, "must be on or after the start date") if start_date && due_date && due_date < start_date
     end

     def reference_links_are_web_addresses
          errors.add(:reference_links_text, LINK_FORMAT_MESSAGE) unless Array(@reference_urls).all? { |url| web_address?(url) }
     end

     def web_address?(url)
          uri = URI.parse(url)
          uri.is_a?(URI::HTTP) && uri.host.present?
     rescue URI::InvalidURIError
          false
     end

     def merge_reference_links
          return unless @reference_urls
          base = instructions_without_reference_links
          self.instructions = @reference_urls.any? ? base + REFERENCE_HEADING + @reference_urls.join("\n") : base
          @reference_urls = nil
     end

     def status_actor_is_authorized
          return unless new_record? || will_save_change_to_status?
          actor = new_record? ? creator : acting_user
          return if actor && (actor.can_manage?(self) || (persisted? && actor.can_work_on?(self)))

          errors.add(:status, "requires an authorized person making the change")
     end

     def assignments_remain_in_team
          return unless persisted? && will_save_change_to_project_id?
          invalid = active_assignments.joins(user: { membership: :subteam }).where.not(subteams: { team_id: team_id })
          errors.add(:project, "would invalidate active assignments") if invalid.exists?
          if task_dependencies.exists? || dependent_links.exists?
               errors.add(:project, "cannot move to another team while prerequisites are linked") if Project.where(id: project_id_in_database).pick(:team_id) != team_id
          end
     end

     def record_initial_status
          status_changes.create!(actor: creator, to_status: status, created_at: created_at)
     end

     def record_status_change
          status_changes.create!(actor: acting_user, to_status: status, created_at: Time.current)
     end
end
