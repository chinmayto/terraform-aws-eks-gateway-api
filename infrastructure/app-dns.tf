####################################################################################
### Route53 Hosted Zone
####################################################################################
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

####################################################################################
### Route53 DNS Record for Node.js App (to be created after Gateway deployment)
####################################################################################
# Note: This DNS record should be created after the Gateway is deployed
# Use the following command to get the LoadBalancer hostname:
# kubectl get gateway app-gateway -n gateway-system -o jsonpath='{.status.addresses[0].value}'
# 
# Then create the DNS record manually or use the provided script

# Uncomment and update the hostname after Gateway deployment:
# resource "aws_route53_record" "nodejs_app" {
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = var.app_subdomain
#   type    = "A"
#
#   alias {
#     name                   = "YOUR_GATEWAY_LOADBALANCER_HOSTNAME_HERE"
#     zone_id                = "Z26RNL4JYFTOTI" # NLB zone ID for us-east-1
#     evaluate_target_health = true
#   }
# }
