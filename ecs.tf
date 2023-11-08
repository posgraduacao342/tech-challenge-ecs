module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = "tech-challenge-cluster"

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/aws-ec2"
      }
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "example" {
  cluster_name = module.ecs.cluster_name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_ecs_task_definition" "tech_challenge_api" { 
  family                   = "tech-challenge-api"
  network_mode             = "awsvpc"
  execution_role_arn       = "arn:aws:iam::623546275946:role/ecsTaskExecutionRole"
  cpu                      = "1024"
  memory                   = "3072"
  requires_compatibilities = ["FARGATE"]

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "tech-challenge-api-container"
      image     = "623546275946.dkr.ecr.us-east-1.amazonaws.com/tech-challenge-api:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]

      environment = [
        {
          name  = "DATASOURCE_URL",
          value = var.datasource_url
        },
        {
          name  = "DATASOURCE_USERNAME",
          value = var.datasource_username
        },
        {
          name  = "DATASOURCE_PASSWORD",
          value = var.datasource_password
        },
        {
          name  = "MP_WEBHOOK ",
          value = var.mp_webhook
        },
        {
          name  = "MP_TOKEN",
          value = var.mp_token
        }
      ]

      environmentFiles = []

      mountPoints = []
      volumesFrom = []

      ulimits = []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-create-group"  = "true"
          "awslogs-group"         = "/ecs/tech-challenge-api"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
        secretOptions = []
      }


    }
  ])
}

resource "aws_ecs_service" "tech_challenge_service" {
  name            = "tech-challenge-service"
  cluster         = "arn:aws:ecs:us-east-1:623546275946:cluster/tech-challenge-cluster"
  task_definition = aws_ecs_task_definition.tech_challenge_api.arn
  desired_count   = 1

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 3
  }

  network_configuration {
    subnets          = data.aws_subnets.this.ids
    security_groups  = [aws_security_group.ecs_security_group.id] # Especifique os grupos de segurança apropriados
    assign_public_ip = true
  }

  depends_on = [aws_security_group.ecs_security_group]
}

resource "aws_security_group" "ecs_security_group" {
  name_prefix = "ecs-tech-challenge-security-group"
  description = "Security group for ECS tech-challenge service"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}