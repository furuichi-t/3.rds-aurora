#VPC
resource "aws_vpc" "tf-vpc" { 
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "tf-subnet" {
  vpc_id = aws_vpc.tf-vpc.id
  cidr_block = "10.0.10.0/24"
  availability_zone = "ap-northeast-1a"
}

resource "aws_internet_gateway" "tf-igw" { 
  vpc_id = aws_vpc.tf-vpc.id
}

resource "aws_route_table" "tf-route-table" { 
  vpc_id = aws_vpc.tf-vpc.id
}

resource "aws_route" "tf-route" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.tf-igw.id
  route_table_id = aws_route_table.tf-route-table.id
}

resource "aws_route_table_association" "tf-rt-associate" {
  route_table_id = aws_route_table.tf-route-table.id
  subnet_id = aws_subnet.tf-subnet.id
}

#EC2
resource "tls_private_key" "tf-private" { 
  algorithm = "RSA"
  rsa_bits = 2048 
}

resource "aws_key_pair" "tf-key" { 
  key_name = "furuichi-tf"
  public_key = tls_private_key.tf-private.public_key_openssh
}

resource "aws_security_group" "tf-sg" { 
  name = "furuichi-tf-sg"
  vpc_id = aws_vpc.tf-vpc.id
  ingress  {
    from_port = 80
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "tf-eip" { 
  instance = aws_instance.tf-ec2.id 
}

resource "aws_instance" "tf-ec2" { 
  instance_type = "t2.micro" 
  ami = "ami-08fb04789426cd124" 
  key_name = aws_key_pair.tf-key.id 
  subnet_id = aws_subnet.tf-subnet.id 
  vpc_security_group_ids = [aws_security_group.tf-sg.id] 
   
  user_data = <<-E0F
           #!/bin/bash
           yum -y install httpd php mysql php-mysql

           case $(ps -p 1 -o comm | tail -1) in
           systemd) systemctl enable --now httpd ;;
           init) chkconfig httpd on; service httpd start ;;
           *) echo "Error starting httpd (OS not using init or systemd)." 2>&1
           esac

           if [ ! -f /var/www/html/bootcamp-app.tar.gz ]; then
           cd /var/www/html
           wget https://s3.amazonaws.com/immersionday-labs/bootcamp-app.tar
           tar xvf bootcamp-app.tar
           chown apache:root /var/www/html/rds.conf.php
           fi
           yum -y update
           E0F
}

resource "local_file" "private_key" { 
  filename = "/home/furuichi-ubuntu/rds-aurora/deployer.pem" 
  content  = tls_private_key.tf-private.private_key_pem 
  file_permission = "0600" 
} 

#RDS
resource "aws_security_group" "tf-db-sg" { 
  name = "furuichi-db-sg"
  vpc_id = aws_vpc.tf-vpc.id
    ingress  {
    from_port = 3306
    to_port = 3306
    security_groups = [aws_security_group.tf-sg.id]
    protocol = "tcp"
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "tf-private1" { 
  vpc_id = aws_vpc.tf-vpc.id
  cidr_block = "10.0.20.0/24"
  availability_zone = "ap-northeast-1a"
}

resource "aws_subnet" "tf-private2" {
  vpc_id = aws_vpc.tf-vpc.id
  cidr_block = "10.0.30.0/24"
  availability_zone = "ap-northeast-1c"
}

resource "aws_db_subnet_group" "tf-db-subnet" { 
  name = "tf-praivate-subnet"
  subnet_ids = [ aws_subnet.tf-private1.id, aws_subnet.tf-private2.id ]
}

resource "aws_db_parameter_group" "tf-db-parameter" {
  family = "mysql5.7" 

  parameter {
    value = "utf8mb4"
    name = "character_set_database"
  }
#RDSを読み取り専用にするコード
#  parameter {  #auroraインスタンスを作成したのちここでRDSをリードレプリカに変更する
 #   name = "read_only"
  #  value = "1"
  #}
}

resource "aws_db_instance" "tf-db-instance" { 
  identifier = "rdsdb"
  allocated_storage = 20
  db_name = "mydb"
  engine = "mysql"
  port = 3306
  engine_version = "5.7.44"
  instance_class = "db.t3.micro"
  vpc_security_group_ids = [ aws_security_group.tf-db-sg.id ] 
  skip_final_snapshot = true 
  username = var.db_username 
  password = var.db_password 
  parameter_group_name = aws_db_parameter_group.tf-db-parameter.name 
  db_subnet_group_name = aws_db_subnet_group.tf-db-subnet.name 
  backup_retention_period = 1 
}

#Aurora 移行ハンズオンをする際はここから下はコメントアウトしてRDSを作った後にコメントアウトを外しデプロイする　
#resource "aws_rds_cluster" "tf-aurora-cluster" {
#  replication_source_identifier = aws_db_instance.tf-db-instance.arn
#  cluster_identifier = "aurora-db"
#  engine = "aurora-mysql"
#  engine_version = "5.7.mysql_aurora.2.11.5"
#  availability_zones = ["ap-northeast-1a", "ap-northeast-1c"]
#  db_subnet_group_name = aws_db_subnet_group.tf-db-subnet.name
#  vpc_security_group_ids = [ aws_security_group.tf-db-sg.id ] 
#  port = 3306
#  skip_final_snapshot = true
#  db_cluster_parameter_group_name = "default.aurora-mysql5.7"
#  backup_retention_period = 1 
#  apply_immediately = true
#}
#auroraを構築し終わった後にコメントアウトを外す　一回しか行わないコマンドなのでターミナルでコマンド入力しても可
#resource "null_resource" "promote_aurora_replica" {   #auroraレプリカをawscliコマンドを使いスタンドアローンに昇格させるコード
  #triggers = {
   # always_run = "${timestamp()}"
  #}

  #provisioner "local-exec" {
  #  command = "aws rds promote-read-replica-db-cluster --db-cluster-identifier aurora-db"
 # }
#}


#resource "aws_rds_cluster_instance" "instance1" { 
#  cluster_identifier = aws_rds_cluster.tf-aurora-cluster.id 
#  identifier = "aurora-reader"
#  instance_class = "db.t3.small"
#  engine = aws_rds_cluster.tf-aurora-cluster.engine
#  engine_version = aws_rds_cluster.tf-aurora-cluster.engine_version
#  db_parameter_group_name = "default.aurora-mysql5.7" 
#  promotion_tier = 1 
#  apply_immediately = true

#  lifecycle {
#    create_before_destroy = true
#  }
#}

#resource "aws_rds_cluster_instance" "instance2" {
#  cluster_identifier = aws_rds_cluster.tf-aurora-cluster.id
#  identifier = "aurora-writer"
#  instance_class = "db.t3.small"
#  engine = aws_rds_cluster.tf-aurora-cluster.engine
#  engine_version = aws_rds_cluster.tf-aurora-cluster.engine_version
#  db_parameter_group_name = "default.aurora-mysql5.7"
#  promotion_tier = 15
#  apply_immediately = true

#  lifecycle {
#    create_before_destroy = true
#  }
#}

