variable my_dev_project1 {

  default = "dev-project-9219"
  }

variable my_prod_project2 {
  default = "prd-priject-9219"
  
}

resource "google_compute_network" "vpc_networkprod" {
  name = "vpc-network-1"
  project = var.my_prod_project2
  routing_mode = "GLOBAL"
  auto_create_subnetworks = false
}
resource "google_compute_network" "vpc_networkdev" {
  name = "vpc-network-2"
  project = var.my_dev_project1
  routing_mode = "GLOBAL"
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "subnetwork_dev" {
  name          = "mysubnet-2"
  ip_cidr_range = "10.10.12.0/24"
  region        = "us-west1"
  network       = "${google_compute_network.vpc_networkdev.name}"
  project    = var.my_dev_project1
}
resource "google_compute_subnetwork" "subnetwork_prod" {
  name          = "mysubnet-2"
  ip_cidr_range = "10.10.11.0/24"
  region        = "us-west1"
  network       = "${google_compute_network.vpc_networkprod.name}"
  project      = var.my_prod_project2
}

resource "google_compute_firewall" "prod_firewall" {
  name    = "prod-firewall"
  network = "${google_compute_network.vpc_networkprod.name}"
  project = var.my_prod_project2

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["80", "8080", "1000-2000","22"]
  }

  source_tags = ["web"]
  source_ranges = ["0.0.0.0/0"]
}
resource "google_compute_firewall" "dev_firewall" {
  name    = "dev-firewall"
  network = "${google_compute_network.vpc_networkdev.name}"
  project = var.my_dev_project1

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["80", "8080", "1000-2000","22"]
  }

  source_tags = ["web"]
  source_ranges = ["0.0.0.0/0"]
}
resource "google_compute_network_peering" "peering1" {
  name         = "peering1"
  network      = "${google_compute_network.vpc_networkprod.id}"
  peer_network = "${google_compute_network.vpc_networkdev.id}"
}
resource "google_compute_network_peering" "peering2" {
  name         = "peering1"
  network      = "${google_compute_network.vpc_networkdev.id}"
  peer_network = "${google_compute_network.vpc_networkprod.id}"
}
resource "google_compute_instance" "prod" {
  name         = "test"
  machine_type = "n1-standard-1"
  zone         = "us-west1-c"
  project = var.my_prod_project2

  tags = ["foo", "bar"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }
  network_interface {
    network = "${google_compute_network.vpc_networkprod.name}"
    subnetwork = "${google_compute_subnetwork.subnetwork_prod.name}"
    subnetwork_project = "prd-priject-9219"
    access_config {
      
    }
  }
}
resource "google_compute_instance" "dev" {
  name         = "test1"
  machine_type = "n1-standard-1"
  zone         = "us-west1-c"
  project = var.my_dev_project1

  tags = ["foo", "bar"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }
  network_interface {
    network = "${google_compute_network.vpc_networkdev.name}"
    subnetwork = "${google_compute_subnetwork.subnetwork_dev.name}"
    subnetwork_project = "dev-project-9219"
    access_config {
      
    }
  }
}
resource "google_container_cluster" "primary" {
  name               = "marcellus-wallace"
  location           = "us-central1-a"
  initial_node_count = 3
  project = "dev-project-9219"

  master_auth {
    username = "username"
    password = "pass"

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    metadata = {
      disable-legacy-endpoints = "true"
    }

    labels = {
      app = "wordpress"
    }

    tags = ["website", "wordpress"]
  }

  timeouts {
    create = "30m"
    update = "40m"
  }
}
resource "null_resource" "nullremote1" {
  depends_on = [google_container_cluster.primary]
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${google_container_cluster.primary.location} --project ${google_container_cluster.primary.project}"
    }
}
resource "kubernetes_service" "example" {
  depends_on = [null_resource.nullremote1]
  metadata {
    name = "loadbalancer"
  }
  spec {
    selector = {
      app = "${kubernetes_pod.example.metadata.0.labels.app}"
    }
    session_affinity = "ClientIP"
    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_pod" "example" {
  metadata {
    name = "terraform-example"
    labels = {
      app = "MyApp"
    }
  }

  spec {
    container {
      image = "wordpress:4.8-apache"
      name  = "mywp"
    }
  }
}

output "wordpressip" {
          value = kubernetes_service.example.load_balancer_ingress
  

}
resource "google_sql_database" "database" {
  name     = "my-database1"
  instance = google_sql_database_instance.instance.name
  project = "prd-priject-9219"
}

resource "google_sql_database_instance" "instance" {
  name   = "my-database-instance42"
  database_version = "MYSQL_5_6"
  region = "us-central1"
  project = "prd-priject-9219"
  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name = "public  network"
        value = "0.0.0.0/0"
      }
    }
  }
}
resource "google_sql_user" "users" {
  name     = "myuser"
  instance = google_sql_database_instance.instance.name
  project =  "prd-priject-9219"
  password = "redhat"
}
