#! /bin/bash

# This script retrieves all DNS records from AWS Route53 DNS zone and imports all of them to Terraform

zone_name='justinpriest.io'
zone_id='Z090532525QOMOVVU3L9X'
#aws_profile='example_com'

# Get zone slug from zone name
zone_slug=$(echo ${zone_name} | tr '.' '-')

# Get DNS zone current data from AWS
zone="$(aws --profile=${aws_profile} route53 list-hosted-zones | jq '.HostedZones[] | select (.Id | contains("'${zone_id}'"))')"
# Another method to get DNS zone data searching by zone name instead of zone ID
#zone="$(aws --profile=${aws_profile} route53 list-hosted-zones | jq '.HostedZones[] | select (.Name=="'${zone_name}'.")')"
zone_comment="$(echo ${zone} | jq '.Comment')"
if [ "${zone_comment}" == 'null' ];then
    zone_comment="${zone_name} zone"
fi

# Write aws_route53_zone resource to terraform file
cat << EOF > dns-zone-${zone_name}.tf
resource "aws_route53_zone" "${zone_slug}" {
    name         = "${zone_name}"
    comment      = "${zone_comment}"
}
EOF

# Import DNS zone and records from file to terraform
terraform import "aws_route53_zone.${zone_slug}" "${zone_id}"

# Retrieve all regular records (not alias) from DNS zone and write them down to terraform file
IFS=$'\n'
for dns_record in $(aws --profile="${aws_profile}" route53 list-resource-record-sets --hosted-zone-id "${zone_id}" | jq -c '.ResourceRecordSets[] | select(has("AliasTarget") | not)');do
    name="$(echo ${dns_record} | jq -r '.Name')"
    type="$(echo ${dns_record} | jq -r '.Type')"
    name_slug="$(echo ${type}-${name} | sed -E 's/[\._\ ]+/-/g' | sed -E 's/(^-|-$)//g')"
    ttl="$(echo ${dns_record} | jq -r '.TTL')"
    records="$(echo ${dns_record} | jq -cr '.ResourceRecords' | jq '.[].Value' | sed 's/$/,/')"
    records="$(echo ${records} | sed 's/,$//')"

    cat << EOF >> dns-zone-${zone_name}.tf

resource "aws_route53_record" "${name_slug}" {
    zone_id = aws_route53_zone.${zone_slug}.zone_id
    name    = "${name}"
    type    = "${type}"
    ttl     = "${ttl}"
    records = [${records}]
}
EOF

    # Import DNS record to Terraform
    terraform import "aws_route53_record.${name_slug}" "${zone_id}_${name}_${type}"
done

# Retrieve all alias records from DNS zone and write them down to terraform file
IFS=$'\n'
for dns_record in $(aws --profile="${aws_profile}" route53 list-resource-record-sets --hosted-zone-id "${zone_id}" | jq -c '.ResourceRecordSets[] | select(has("AliasTarget"))');do
    name="$(echo ${dns_record} | jq -r '.Name')"
    type="$(echo ${dns_record} | jq -r '.Type')"
    name_slug="$(echo ${type}-${name} | sed -E 's/[\._\ ]+/-/g' | sed -E 's/(^-|-$)//g')"
    alias_name="$(echo ${dns_record} | jq -cr '.AliasTarget' | jq -r '.DNSName')"

    cat << EOF >> dns-zone-${zone_name}.tf

resource "aws_route53_record" "${name_slug}" {
    zone_id = aws_route53_zone.${zone_slug}.zone_id
    name    = "${name}"
    type    = "${type}"

    alias {
        name                   = "${alias_name}" 
        zone_id                = "${zone_id}"
        evaluate_target_health = true
    }
}
EOF

    # Import DNS record to Terraform
    terraform import "aws_route53_record.${name_slug}" "${zone_id}_${name}_${type}"
done