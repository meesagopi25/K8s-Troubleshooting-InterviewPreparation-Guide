
output "new_asg_name" {
  description = "Name of the newly created Auto Scaling Group"
  value       = aws_autoscaling_group.workers_v2.name
}

output "new_launch_template_id" {
  description = "Launch Template ID for new worker nodes"
  value       = aws_launch_template.workers_v2.id
}

output "new_launch_template_version" {
  description = "Latest launch template version"
  value       = aws_launch_template.workers_v2.latest_version
}

output "worker_node_labels" {
  description = "Node label applied to new worker nodes"
  value       = "nodegroup=workers-v2"
}
