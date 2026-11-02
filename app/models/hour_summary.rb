# Each member's estimated vs. actual hours for the tasks on the board, over an
# optional date range (scope S07). Shown to leaders below the task board.
class HourSummary
     MemberRow = Struct.new(:member, :tasks, :estimate, :actual)

     attr_reader :tasks, :from, :to, :errors

     def initialize(tasks:, from: nil, to: nil, members: nil, member_id: nil)
          @tasks = tasks
          @included_members = members
          @member_id = member_id
          @errors = []
          @from = parse_date(from, "Start date")
          @to = parse_date(to, "End date")
          return unless @from && @to && @to < @from

          @errors << "End date must be on or after the start date"
          @from = @to = nil
     end

     def member_rows
          @member_rows ||= members.map do |member|
               assigned = tasks.select { |task| task.assignees.include?(member) }
               MemberRow.new(member, assigned, assigned.sum(&:estimated_hours), actual_hours_for(member))
          end
     end

     # Each task estimate is counted once, however many members share it.
     def total_estimate
          tasks.sum(&:estimated_hours)
     end

     def total_actual
          entries_in_range.sum(&:hours)
     end

     def chart_scale
          [ *member_rows.map(&:estimate), *member_rows.map(&:actual), 1 ].max
     end

     def actual_for_task(task)
          entries_in_range.select { |entry| entry.task_id == task.id }.sum(BigDecimal("0"), &:hours)
     end

     private

     def members
          rows = (@included_members ? @included_members.to_a : tasks.flat_map(&:assignees) + entries_in_range.map(&:user)).uniq
          rows = rows.select { |member| member.id == @member_id } if @member_id
          rows.sort_by { |member| [ member.name, member.id ] }
     end

     def entries_in_range
          @entries_in_range ||= tasks.flat_map(&:time_entries).select do |entry|
               (from.nil? || entry.worked_on >= from) && (to.nil? || entry.worked_on <= to) &&
                    (@member_id.nil? || entry.user_id == @member_id)
          end
     end

     def actual_hours_for(member)
          entries_in_range.select { |entry| entry.user_id == member.id }.sum(BigDecimal("0"), &:hours)
     end

     def parse_date(value, label)
          return if value.blank?

          Date.iso8601(value)
     rescue Date::Error
          @errors << "#{label} is not a valid date"
          nil
     end
end
