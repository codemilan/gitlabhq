class DeleteMergedBranchesService < BaseService
  def async_execute
    DeleteMergedBranchesWorker.perform_async(project.id, current_user.id)
  end

  def execute
    raise Gitlab::Access::AccessDeniedError unless can?(current_user, :push_code, project)

    branches = project.repository.branch_names
    branches = branches.select { |branch| project.repository.merged_to_root_ref?(branch) }
    # Prevent deletion of branches relevant to open merge requests
    branches -= merge_request_branch_names
    # Prevent deletion of protected branches
    branches = branches.reject { |branch| project.protected_for?(branch) }

    branches.each do |branch|
      DeleteBranchService.new(project, current_user).execute(branch)
    end
  end

  private

  def merge_request_branch_names
    # reorder(nil) is necessary for SELECT DISTINCT because default scope adds an ORDER BY
    source_names = project.origin_merge_requests.opened.reorder(nil).uniq.pluck(:source_branch)
    target_names = project.merge_requests.opened.reorder(nil).uniq.pluck(:target_branch)
    (source_names + target_names).uniq
  end
end
