
resource "aws_autoscaling_group" "workers_v2" {
  name                = "eks-workers-v2"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.workers_v2.id
    version = "$Latest"
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "nodegroup"
    value               = "workers-v2"
    propagate_at_launch = true
  }
}
