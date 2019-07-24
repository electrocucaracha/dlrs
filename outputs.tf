output "instance_ips" {
  value = ["${aws_instance.dlrs_cpu_instance.*.public_ip}", "${aws_instance.dlrs_gpu_instance.*.public_ip}"]
}
