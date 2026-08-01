class AddIpAddressAndUserAgentToWorkflowSteps < ActiveRecord::Migration[8.1]
  def change
    add_column :workflow_steps, :ip_address, :string
    add_column :workflow_steps, :user_agent, :string
  end
end
