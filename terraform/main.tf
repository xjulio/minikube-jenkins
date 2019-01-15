provider "kubernetes" {
  config_context = "minikube"
}

# jenkins resources
resource "kubernetes_deployment" "jenkins" {
  metadata {
    name = "jenkins"
    namespace = "jenkins"
    labels {
      name = "jenkins"
    }
  }

  spec {
  	replicas = 1
    selector {
      match_labels {
        name = "jenkins"
      }
    }  

    template {
      metadata {
        labels {
          name = "jenkins"
        }
      }

      spec {
        container {
          image = "jenkins:custom"
          name = "jenkins"
          image_pull_policy = "IfNotPresent"
          port {
            container_port = 8080
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "jenkins" {
  metadata {
    name = "jenkins-service"
    namespace = "jenkins"
  }
  spec {
    selector {
      name = "${kubernetes_deployment.jenkins.metadata.0.labels.name}"
    }
    port {
      port = 9000
      target_port = 8080
    }

    type = "NodePort"
  }
}