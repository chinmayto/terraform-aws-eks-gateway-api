#!/bin/bash

# Script to configure DNS after Gateway deployment
# This script gets the Gateway LoadBalancer hostname and creates the Route53 record

set -e

# Configuration
GATEWAY_NAME="app-gateway"
GATEWAY_NAMESPACE="gateway-system"
SUBDOMAIN="app"
DOMAIN="chinmayto.com"
AWS_REGION="us-east-1"

echo "Waiting for Gateway to be ready..."

# Wait for Gateway to have an address
while true; do
    GATEWAY_ADDRESS=$(kubectl get gateway $GATEWAY_NAME -n $GATEWAY_NAMESPACE -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "")
    
    if [ -n "$GATEWAY_ADDRESS" ]; then
        echo "Gateway LoadBalancer address found: $GATEWAY_ADDRESS"
        break
    else
        echo "Waiting for Gateway LoadBalancer to be provisioned..."
        sleep 30
    fi
done

# Get the hosted zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name $DOMAIN --query "HostedZones[0].Id" --output text | sed 's|/hostedzone/||')

if [ "$HOSTED_ZONE_ID" = "None" ] || [ -z "$HOSTED_ZONE_ID" ]; then
    echo "Error: Could not find hosted zone for domain $DOMAIN"
    exit 1
fi

echo "Found hosted zone ID: $HOSTED_ZONE_ID"

# Create the Route53 record
echo "Creating Route53 record for $SUBDOMAIN.$DOMAIN -> $GATEWAY_ADDRESS"

# Get the zone ID for NLB (us-east-1)
NLB_ZONE_ID="Z26RNL4JYFTOTI"

# Create the DNS record
aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch '{
        "Changes": [{
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "'$SUBDOMAIN.$DOMAIN'",
                "Type": "A",
                "AliasTarget": {
                    "DNSName": "'$GATEWAY_ADDRESS'",
                    "EvaluateTargetHealth": true,
                    "HostedZoneId": "'$NLB_ZONE_ID'"
                }
            }
        }]
    }'

echo "DNS record created successfully!"
echo "Your application will be available at: http://$SUBDOMAIN.$DOMAIN"
echo "Note: DNS propagation may take a few minutes."