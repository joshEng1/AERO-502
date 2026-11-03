require "csv"

class ReportCsv
     TASK_HEADERS = [ "Task", "Project", "Class", "Subteam", "Assignees", "Status", "Start date", "Due date", "Estimated hours", "Actual hours" ].freeze
     MEMBER_HEADERS = [ "Member", "Class", "Subteam", "Project", "Total actual hours" ].freeze

     def self.tasks(report)
          generate(TASK_HEADERS, report.tasks.map do |task|
               [ task.title, task.project.name, task.team.name, task.subteam_names,
                 task.assignees.sort_by(&:name).map(&:name).join("; "), task.status.humanize,
                 task.start_date.iso8601, task.due_date.iso8601, task.estimated_hours.to_d.to_s("F"), report.hours.actual_for_task(task).to_s("F") ]
          end)
     end

     def self.members(report, project_name: "All selected projects")
          generate(MEMBER_HEADERS, report.hours.member_rows.map do |row|
               [ row.member.name, row.member.team.name, row.member.subteam.name,
                 project_name, row.actual.to_s("F") ]
          end)
     end

     def self.projects(report)
          generate([ "Project", "Class", "Subteam", "Total actual hours" ], report.tasks.group_by(&:project).map do |project, tasks|
               [ project.name, project.team.name, tasks.flat_map(&:subteams).map(&:name).uniq.sort.join("; "),
                 tasks.sum { |task| report.hours.actual_for_task(task) }.to_d.to_s("F") ]
          end)
     end

     # Quotes preserve commas, newlines and accents. Prefix formula-like text.
     def self.generate(headers, rows)
          "\uFEFF" + CSV.generate(row_sep: "\r\n", force_quotes: true) do |csv|
               csv << headers
               rows.each do |row|
                    csv << row.map { |value| value.to_s.match?(/\A[\s\u0000-\u001f]*[=+@-]/) ? "'#{value}" : value }
               end
          end
     end
end
