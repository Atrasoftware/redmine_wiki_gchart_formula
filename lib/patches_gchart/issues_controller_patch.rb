require_dependency 'issues_controller'

module  PatchesGchart
  module IssuesControllerPatch
    def self.included(base)
      base.extend(ClassMethods)

      base.send(:include, InstanceMethods)
      base.class_eval do
        alias_method_chain :show, :change_pdf
      end
    end

  end

  module ClassMethods
  end

  module InstanceMethods

    def show_with_change_pdf
      @journals = @issue.journals.includes(:user, :details).reorder("#{Journal.table_name}.id ASC").all
      @journals.each_with_index {|j,i| j.indice = i+1}
      @journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @issue.project)
      Journal.preload_journals_details_custom_fields(@journals)
      # TODO: use #select! when ruby1.8 support is dropped
      @journals.reject! {|journal| !journal.notes? && journal.visible_details.empty?}
      @journals.reverse! if User.current.wants_comments_in_reverse_order?

      @changesets = @issue.changesets.visible.all
      @changesets.reverse! if User.current.wants_comments_in_reverse_order?

      @relations = @issue.relations.select {|r| r.other_issue(@issue) && r.other_issue(@issue).visible? }
      @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
      @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
      @priorities = IssuePriority.active
      @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
      @relation = IssueRelation.new

      respond_to do |format|
        format.html {
          retrieve_previous_and_next_issue_ids
          render :template => 'issues/show'
        }
        format.api
        format.atom { render :template => 'journals/index', :layout => false, :content_type => 'application/atom+xml' }
        format.pdf  {
          render pdf: 'issue'
        }
      end
    end
  end
end