data "template_file" "data_userdata_script" {
  template = "${file("${path.root}/../templates/user_data.sh")}"

  vars {
    volume_name             = "${var.volume_name}"
    elasticsearch_data_dir  = "${var.elasticsearch_data_dir}"
    elasticsearch_logs_dir  = "${var.elasticsearch_logs_dir}"
    heap_size               = "${var.data_heap_size}"
    es_cluster              = "${var.es_cluster}"
    es_environment          = "${var.environment}-${var.es_cluster}"
    security_groups         = "${aws_security_group.elasticsearch_security_group.id}"
    aws_region              = "${var.aws_region}"
    availability_zones      = "${var.availability_zones}"
    minimum_master_nodes    = "${format("%d", var.masters_count / 2 + 1)}"
    master                  = "false"
    data                    = "true"
    http_enabled            = "true"
    security_enabled        = "${var.security_enabled}"
  }
}

resource "aws_launch_configuration" "data" {
  name = "elasticsearch-${var.es_cluster}-data-nodes"
  image_id = "${data.aws_ami.elasticsearch.id}"
  instance_type = "${var.data_instance_type}"
  security_groups = ["${aws_security_group.elasticsearch_security_group.id}"]
  associate_public_ip_address = false
  iam_instance_profile = "${aws_iam_instance_profile.elasticsearch.id}"
  user_data = "${data.template_file.data_userdata_script.rendered}"
  key_name = "${var.key_name}"

  ebs_optimized = true

  lifecycle {
    create_before_destroy = true
  }

  ebs_block_device {
    device_name = "${var.volume_name}"
    volume_size = "${var.elasticsearch_volume_size}"
    encrypted = "${var.volume_encryption}"
  }
}

resource "aws_autoscaling_group" "data_nodes" {
  name = "elasticsearch-${var.es_cluster}-data-nodes"
  max_size = "${var.datas_count}"
  min_size = "${var.datas_count}"
  desired_capacity = "${var.datas_count}"
  default_cooldown = 30
  force_delete = true
  launch_configuration = "${aws_launch_configuration.data.id}"

  vpc_zone_identifier = ["${var.vpc_subnets}"]

  depends_on = ["aws_autoscaling_group.master_nodes"]

  tag {
    key                 = "Name"
    value               = "${format("%s-data-node", var.es_cluster)}"
    propagate_at_launch = true
  }

  tag {
    key = "Environment"
    value = "${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key = "Cluster"
    value = "${var.environment}-${var.es_cluster}"
    propagate_at_launch = true
  }

  tag {
    key = "Role"
    value = "data"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}