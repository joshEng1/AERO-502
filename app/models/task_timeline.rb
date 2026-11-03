# Lays tasks out on a Gantt-style date window (scope S11). The window starts on
# a Monday and spans whole weeks; each bar runs from start date to due date.
# Instead of paging through fixed windows, the window stretches to cover every
# task shown and the page scrolls sideways through it (JD's Sprint 2 feedback).
class TaskTimeline
     MIN_WEEKS = 6
     # Keeps the chart a sensible width when a task has far-off dates; tasks
     # beyond these limits are marked "Earlier" or "Later" on their row.
     MAX_WEEKS_BEFORE = 26
     MAX_WEEKS_AFTER = 52

     Bar = Struct.new(:offset, :span, :clipped_start, :clipped_end, keyword_init: true)

     attr_reader :from, :to, :tasks

     def initialize(tasks:)
          @tasks = tasks
          earliest = Date.current - MAX_WEEKS_BEFORE.weeks
          latest = Date.current + MAX_WEEKS_AFTER.weeks
          first = [ tasks.map(&:start_date).min, Date.current - 1.week ].compact.min
          @from = [ first, earliest ].max.beginning_of_week
          last = [ tasks.map(&:due_date).max, from + (MIN_WEEKS * 7) - 1 ].compact.max
          @to = [ last, latest ].min.end_of_week
     end

     def days
          (from..to).to_a
     end

     def week_starts
          days.each_slice(7).map(&:first)
     end

     def today_offset
          (Date.current - from).to_i if Date.current.between?(from, to)
     end

     # Tasks grouped by team, then subteam, each sorted by name and start date.
     def groups
          tasks.group_by(&:team).sort_by { |team, _| team.name }.map do |team, team_tasks|
               subteams = team_tasks.group_by(&:subteam).sort_by { |subteam, _| subteam.name }
               [ team, subteams.map { |subteam, rows| [ subteam, rows.sort_by { |task| [ task.start_date, task.title ] } ] } ]
          end
     end

     # Where a task's bar sits in the window, or nil when it falls outside it.
     def bar_for(task)
          return if task.due_date < from || task.start_date > to

          first = [ task.start_date, from ].max
          last = [ task.due_date, to ].min
          Bar.new(offset: (first - from).to_i, span: (last - first).to_i + 1,
                  clipped_start: task.start_date < from, clipped_end: task.due_date > to)
     end
end
