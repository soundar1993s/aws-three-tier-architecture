data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

locals {
  load_balancers = {
    web = { internal = false, security_group = "public-alb", port = 80 }
    app = { internal = true, security_group = "internal-alb", port = 5000 }
  }
}

resource "aws_lb" "tier" {
  for_each           = local.load_balancers
  name               = "${local.project}-${each.key}"
  internal           = each.value.internal
  load_balancer_type = "application"
  subnets            = [for index in range(1, 3) : aws_subnet.tier["${each.key}-${index}"].id]
  security_groups    = [aws_security_group.tier[each.value.security_group].id]
  depends_on         = [aws_route_table_association.tier, aws_route.web]
}

resource "aws_lb_target_group" "tier" {
  for_each = local.load_balancers
  name     = "${local.project}-${each.key}"
  vpc_id   = aws_vpc.project.id
  protocol = "HTTP"
  port     = each.value.port
  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "tier" {
  for_each          = local.load_balancers
  load_balancer_arn = aws_lb.tier[each.key].arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tier[each.key].arn
  }
}

resource "aws_db_subnet_group" "project" {
  name       = local.project
  subnet_ids = [aws_subnet.tier["db-1"].id, aws_subnet.tier["db-2"].id]
}

resource "aws_db_instance" "mysql" {
  identifier                  = "${local.project}-mysql"
  engine                      = "mysql"
  instance_class              = "db.t4g.micro"
  allocated_storage           = 20
  storage_type                = "gp3"
  storage_encrypted           = true
  multi_az                    = var.multi_az_database
  publicly_accessible         = false
  username                    = "admin"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.project.name
  vpc_security_group_ids      = [aws_security_group.tier["db"].id]
  backup_retention_period     = 1
  skip_final_snapshot         = true
}

resource "random_password" "writer" {
  length  = 40
  special = false
}

resource "aws_secretsmanager_secret" "writer" {
  name_prefix = "${local.project}-writer-"
}

resource "aws_secretsmanager_secret_version" "writer" {
  secret_id = aws_secretsmanager_secret.writer.id
  secret_string = jsonencode({
    username = "feedback_writer"
    password = random_password.writer.result
  })
}

resource "aws_iam_role" "tier" {
  for_each = local.load_balancers
  name     = "${local.project}-${each.key}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  for_each   = local.load_balancers
  role       = aws_iam_role.tier[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "writer" {
  role = aws_iam_role.tier["app"].id
  name = "ReadFeedbackWriterSecret"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.writer.arn
    }]
  })
}

resource "aws_iam_role_policy" "schema_bootstrap" {
  count = var.enable_schema_bootstrap ? 1 : 0
  role  = aws_iam_role.tier["app"].id
  name  = "TemporarySchemaBootstrap"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_db_instance.mysql.master_user_secret[0].secret_arn
    }]
  })
}

resource "aws_iam_instance_profile" "tier" {
  for_each = local.load_balancers
  name     = "${local.project}-${each.key}"
  role     = aws_iam_role.tier[each.key].name
}

resource "aws_launch_template" "tier" {
  for_each      = local.load_balancers
  name_prefix   = "${local.project}-${each.key}-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  user_data = base64encode(each.key == "web" ? templatefile("${path.module}/deploy/web.sh.tftpl", {
    index_html = file("${path.module}/index.html")
    nginx_conf = replace(file("${path.module}/nginx.conf"), "internal-private-Loadbalancer-DNS", aws_lb.tier["app"].dns_name)
    }) : templatefile("${path.module}/deploy/app.sh.tftpl", {
    app_code      = file("${path.module}/deploy/app.py")
    database_code = file("${path.module}/deploy/database.py")
    aws_region    = var.aws_region
    database_host = aws_db_instance.mysql.address
    master_secret = aws_db_instance.mysql.master_user_secret[0].secret_arn
    writer_secret = aws_secretsmanager_secret.writer.arn
  }))
  iam_instance_profile {
    name = aws_iam_instance_profile.tier[each.key].name
  }
  metadata_options {
    http_tokens = "required"
  }
  network_interfaces {
    associate_public_ip_address = each.key == "web"
    security_groups             = [aws_security_group.tier[each.key].id]
  }
  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.project}-${each.key}", Project = local.project, Tier = each.key }
  }
}

resource "aws_autoscaling_group" "tier" {
  for_each                  = local.load_balancers
  name                      = "${local.project}-${each.key}"
  min_size                  = 2
  max_size                  = 3
  desired_capacity          = 2
  health_check_type         = "ELB"
  health_check_grace_period = 600
  vpc_zone_identifier       = [for index in range(1, 3) : aws_subnet.tier["${each.key}-${index}"].id]
  target_group_arns         = [aws_lb_target_group.tier[each.key].arn]
  launch_template {
    id      = aws_launch_template.tier[each.key].id
    version = aws_launch_template.tier[each.key].latest_version
  }
  instance_refresh {
    strategy = "Rolling"
  }
  lifecycle {
    ignore_changes = [desired_capacity]
  }
  depends_on = [
    aws_lb_listener.tier, aws_route.app, aws_route_table_association.tier,
    aws_vpc_security_group_ingress_rule.tier, aws_vpc_security_group_egress_rule.tier,
    aws_vpc_security_group_egress_rule.bootstrap, aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy.writer, aws_secretsmanager_secret_version.writer
  ]
}

resource "aws_autoscaling_policy" "cpu" {
  for_each               = local.load_balancers
  name                   = "${local.project}-${each.key}-cpu"
  autoscaling_group_name = aws_autoscaling_group.tier[each.key].name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60
  }
}

output "application_url" {
  value = "http://${aws_lb.tier["web"].dns_name}"
}

output "internal_alb_dns" {
  value = aws_lb.tier["app"].dns_name
}

output "target_groups" {
  value = { for tier, group in aws_lb_target_group.tier : tier => group.arn }
}

output "vpc_id" {
  value = aws_vpc.project.id
}
