output "ec2-public-ip" { #SSH接続の時にEIPのIPアドレスが必要になるので出力
  value = aws_eip.tf-eip.public_ip
}

output "WebsiteURL" {
  value       = "http://${aws_eip.tf-eip.public_ip}/"
  description = "Webserver URL"
}

output "RDSendpoint" {
  value       = aws_db_instance.tf-db-instance.endpoint
  description = "RDS DB instance endpoint"
}

#output "writer_instance_endpoint" { #のちにEC2内で宛先をRDSからauroraに変更する際に必要になる
#  value = aws_rds_cluster_instance.instance2.endpoint
#  description = "writer instance endpoint"
#}
