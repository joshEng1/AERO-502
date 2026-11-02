# Lays tasks out on a Gantt-style date window (scope S11). The window starts on
# a Monday and spans whole weeks; each bar runs from start date to due date.
class TaskTimeline
     WEEK_OPTIONS = [ 4, 6, 8, 12 ].freeze
     DEFAULT_WEEKS = 6

     Bar = Struct.new(:offset, :span, :clipped_start, :clipped_end, keyword_init: true)
     Group = Data.define(:id, :name, :full_name)

     attr_reader :from, :weeks, :tasks

     def initialize(tasks:, from: nil, weeks: nil)
          @tasks = tasks
          @weeks = WEEK_OPTIONS.include?(weeks.to_i) ? weeks.to_i : DEFAULT_WEEKS
          @from = (parse_date(from) || Date.current - 1.week).beginning_of_week
     end

     def to
          from + (weeks * 7) - 1
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

     def previous_from
          from - (weeks * 7)
     end

     def next_from
          from + (weeks * 7)
     end

     # Tasks grouped by team, then subteam, each sorted by name and start date.
     def groups
          tasks.group_by(&:team).sort_by { |team, _| team.name }.map do |team, team_tasks|
               subteams = team_tasks.group_by { |task| task.subteams.sort_by(&:id) }
               groups = subteams.map do |memberships, rows|
                    name = memberships.map(&:name).sort.join("; ").presence || "Unassigned"
                    group = Group.new(memberships.map(&:id).join("-"), name, "#{team.name} · #{name}")
                    [ group, rows.sort_by { |task| [ task.start_date, task.title ] } ]
               end
               [ team, groups.sort_by { |group, _rows| group.name } ]
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

     private

     def parse_date(value)
          Date.iso8601(value.to_s)
     rescue Date::Error
          nil
     end
end
