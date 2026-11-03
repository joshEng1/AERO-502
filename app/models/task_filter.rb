class TaskFilter
     KEYS = %w[q project_id team_id subteam_id member_id task_from task_to].freeze
     attr_reader :query, :project_id, :team_id, :subteam_id, :member_id, :task_from, :task_to, :team_ids, :project_ids

     def initialize(values = {})
          values = values.to_h.stringify_keys
          @query = values["q"].to_s.strip
          %w[project_id team_id subteam_id member_id].each { |key| instance_variable_set("@#{key}", values[key].presence&.to_i) }
          @team_ids = Array(values["team_ids"]).reject(&:blank?).map(&:to_i).uniq
          @project_ids = Array(values["project_ids"]).reject(&:blank?).map(&:to_i).uniq
          @task_from = parse_date(values["task_from"])
          @task_to = parse_date(values["task_to"])
     end

     def to_h
          { "q" => query, "project_id" => project_id, "team_id" => team_id, "subteam_id" => subteam_id,
            "member_id" => member_id, "task_from" => task_from&.iso8601, "task_to" => task_to&.iso8601,
            "team_ids" => team_ids, "project_ids" => project_ids }.compact_blank
     end

     def active?
          to_h.any?
     end

     def selected_team_ids
          ([ team_id ] + team_ids).compact.uniq
     end

     def selected_project_ids
          ([ project_id ] + project_ids).compact.uniq
     end

     def single_project_id
          selected_project_ids.first if selected_project_ids.one?
     end

     def apply(tasks)
          tasks = tasks.in_active_projects
          tasks = tasks.where(project_id: selected_project_ids) if selected_project_ids.any?
          tasks = tasks.where(projects: { team_id: selected_team_ids }) if selected_team_ids.any?
          if subteam_id
               tasks = tasks.where(id: TaskAssignment.active.where(user_id: Membership.where(subteam_id: subteam_id).select(:user_id)).select(:task_id))
          end
          tasks = tasks.where(id: TaskAssignment.active.where(user_id: member_id).select(:task_id)) if member_id
          tasks = tasks.where("tasks.due_date >= ?", task_from) if task_from
          tasks = tasks.where("tasks.start_date <= ?", task_to) if task_to
          if query.present?
               tasks = tasks.where("tasks.title ILIKE :pattern OR tasks.description ILIKE :pattern", pattern: "%#{Task.sanitize_sql_like(query)}%")
          end
          tasks.distinct
     end

     private

     def parse_date(value)
          Date.iso8601(value.to_s)
     rescue Date::Error
          nil
     end
end
