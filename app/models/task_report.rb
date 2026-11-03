# One authorized, distinct task set for summaries and CSV downloads.
class TaskReport
     attr_reader :tasks, :hours

     def initialize(user:, filter:, from: nil, to: nil, tasks: nil)
          @tasks = (tasks || filter.apply(Task.accessible_to(user))).includes(:project, :team, :subteams, :assignees, time_entries: :user).order(:title, :id).to_a.uniq
          cohort = User.where(role: [ :member, :officer ]).joins(:membership)
          cohort = cohort.in_teams(user.team_id) unless user.chief_engineer?
          cohort = cohort.in_teams(filter.selected_team_ids) if filter.selected_team_ids.any?
          cohort = cohort.in_teams(Project.where(id: filter.selected_project_ids).select(:team_id)) if filter.selected_project_ids.any?
          cohort = cohort.in_subteam(filter.subteam_id) if filter.subteam_id
          @hours = HourSummary.new(tasks: @tasks, from: from, to: to, members: cohort.distinct, member_id: filter.member_id)
     end
end
