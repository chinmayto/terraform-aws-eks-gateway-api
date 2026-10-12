####################################################################################
### Route53 DNS — fully managed by Terraform
###
### Flow:
###   1. helm_release.traefik creates a LoadBalancer Service in the traefik namespace
###   2. AWS cloud-controller-manager provisions an NLB (~1-2 min)
###   3. time_sleep.wait_for_nlb gives AWS time to populate the hostname
###   4. data.kubernetes_service_v1.traefik reads the hostname from the Service
###   5. aws_route53_record.nodejs_app creates the A-alias record
####################################################################################

locals {
  # Canonical NLB hosted-zone IDs by region.
  nlb_zone_ids = {
    us-east-1      = "Z26RNL4JYFTOTI"
    us-east-2      = "ZLMOA37VPNGUH"
    us-west-1      = "Z24FKFUX50B4VW"
    us-west-2      = "Z18D5FSROUN65G"
    eu-west-1      = "Z2IFOLAFXWLO4F"
    eu-central-1   = "Z3F0SRJ5LGBH90"
    ap-southeast-1 = "Z19DQILCV0OWEC"
    ap-northeast-1 = "Z31USIVVIZKH4A"
  }

  nlb_hosted_zone_id = local.nlb_zone_ids[var.aws_region]
}

################################################################################
# Wait for AWS to provision the NLB after Traefik's LoadBalancer Service
# is created by the Helm release.  90 seconds is enough in practice; the
# data source below will fail clearly if the hostname is still empty.
################################################################################
resource "time_sleep" "wait_for_nlb" {
  create_duration = "90s"

  depends_on = [helm_release.traefik]
}

################################################################################
# Read the NLB hostname from the Traefik LoadBalancer Service
################################################################################
data "kubernetes_service_v1" "traefik" {
  metadata {
    name      = "traefik"
    namespace = kubernetes_namespace_v1.traefik.metadata[0].name
  }

  depends_on = [time_sleep.wait_for_nlb]
}

################################################################################
# Route53 A-alias record pointing to the Traefik NLB
################################################################################
resource "aws_route53_record" "nodejs_app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.app_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = data.kubernetes_service_v1.traefik.status[0].load_balancer[0].ingress[0].hostname
    zone_id                = local.nlb_hosted_zone_id
    evaluate_target_health = true
  }
}

################################################################################
# Route53 A-alias records for hostname-based routing (Part_01)
#   app1.<domain> -> service-nodejs-app-1
#   app2.<domain> -> service-nodejs-app-2
# Both point to the same Traefik NLB; the HTTPRoute hostnames differentiate them.
################################################################################
resource "aws_route53_record" "nodejs_app_1" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.app1_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = data.kubernetes_service_v1.traefik.status[0].load_balancer[0].ingress[0].hostname
    zone_id                = local.nlb_hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "nodejs_app_2" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.app2_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = data.kubernetes_service_v1.traefik.status[0].load_balancer[0].ingress[0].hostname
    zone_id                = local.nlb_hosted_zone_id
    evaluate_target_health = true
  }
}
