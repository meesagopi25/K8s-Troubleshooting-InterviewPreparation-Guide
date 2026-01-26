resource "aws_launch_template" "workers_v2" {
  name_prefix   = "eks-workers-v2-"
  image_id      = var.worker_ami_id
  instance_type = var.instance_type

  user_data = base64encode(templatefile(
    "${path.module}/bootstrap.sh",
    {
      cluster_name = var.cluster_name
    }
  ))

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name      = "eks-workers-v2"
      nodegroup = "workers-v2"
    }
  }
}

