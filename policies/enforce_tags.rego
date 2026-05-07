# =============================================================================
# Policy: Enforce Mandatory Tags
# =============================================================================
#
# This policy ensures ALL taggable resources include required tags:
#   Project, Environment, ManagedBy
#
# How to test:
#   terraform plan -out=tfplan.binary
#   terraform show -json tfplan.binary > tfplan.json
#   conftest test tfplan.json --policy policies/
#
# =============================================================================

package main

# ─── Configuration ───────────────────────────────────────────────────────────

required_tags := ["Project", "Environment", "ManagedBy"]

taggable_types := {
	"aws_vpc",
	"aws_subnet",
	"aws_internet_gateway",
	"aws_nat_gateway",
	"aws_route_table",
	"aws_eip",
	"aws_security_group",
	"aws_instance",
	"aws_s3_bucket",
	"aws_db_instance",
	"aws_db_subnet_group",
	"aws_db_parameter_group",
}

# ─── Helpers ─────────────────────────────────────────────────────────────────

taggable_resources[resource] {
	resource := input.resource_changes[_]
	taggable_types[resource.type]
	resource.change.actions[_] != "delete"
}

has_valid_tag(resource, tag) {
	value := resource.change.after.tags[tag]
	count(value) > 0
}

has_valid_tag(resource, tag) {
	value := resource.change.after.tags_all[tag]
	count(value) > 0
}

# ─── Rules ───────────────────────────────────────────────────────────────────

deny[msg] {
	resource := taggable_resources[_]
	tag := required_tags[_]
	not has_valid_tag(resource, tag)
	msg := sprintf(
		"DENY: Resource '%s' (type: %s) is missing required tag '%s'. All resources must have: %v",
		[resource.address, resource.type, tag, required_tags],
	)
}
