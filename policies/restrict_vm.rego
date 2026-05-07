# =============================================================================
# Policy: Restrict EC2 Instance Sizes
# =============================================================================
#
# Allowed EC2 types: t2.micro, t2.small, t3.micro, t3.small
# Allowed RDS classes: db.t3.micro, db.t3.small, db.t3.medium
#
# How to test:
#   terraform plan -out=tfplan.binary
#   terraform show -json tfplan.binary > tfplan.json
#   conftest test tfplan.json --policy policies/
#
# =============================================================================

package main

# ─── Configuration ───────────────────────────────────────────────────────────

allowed_instance_types := {
	"t2.micro",
	"t2.small",
	"t3.micro",
	"t3.small",
}

allowed_db_instance_classes := {
	"db.t2.micro",
	"db.t3.micro",
	"db.t3.small",
	"db.t3.medium",
}

# ─── Helpers ─────────────────────────────────────────────────────────────────

ec2_instances[resource] {
	resource := input.resource_changes[_]
	resource.type == "aws_instance"
	resource.change.actions[_] != "delete"
}

rds_instances[resource] {
	resource := input.resource_changes[_]
	resource.type == "aws_db_instance"
	resource.change.actions[_] != "delete"
}

# ─── Rules ───────────────────────────────────────────────────────────────────

deny[msg] {
	resource := ec2_instances[_]
	instance_type := resource.change.after.instance_type
	not allowed_instance_types[instance_type]
	msg := sprintf(
		"DENY: EC2 instance '%s' uses instance type '%s' which is not allowed. Permitted types: %v",
		[resource.address, instance_type, allowed_instance_types],
	)
}

deny[msg] {
	resource := rds_instances[_]
	instance_class := resource.change.after.instance_class
	not allowed_db_instance_classes[instance_class]
	msg := sprintf(
		"DENY: RDS instance '%s' uses class '%s' which is not allowed. Permitted classes: %v",
		[resource.address, instance_class, allowed_db_instance_classes],
	)
}
