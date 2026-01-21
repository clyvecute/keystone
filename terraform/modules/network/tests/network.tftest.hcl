# Network Module Validation Test
# Ensures security constraints are met by the network configuration

run "verify_subnet_config" {
  command = plan

  assert {
    condition     = google_compute_subnetwork.subnet.private_ip_google_access == true
    error_message = "Private Google Access must be enabled for security/compliance"
  }

  assert {
    condition     = length(google_compute_firewall.allow_ssh.source_ranges) > 0
    error_message = "SSH source ranges must be explicitly defined (no empty lists)"
  }
}

run "verify_egress_denial" {
  command = plan

  assert {
    condition     = google_compute_firewall.deny_all_egress.direction == "EGRESS"
    error_message = "Default egress denial rule must be directional"
  }

  assert {
    condition     = anytrue([for d in google_compute_firewall.deny_all_egress.deny : d.protocol == "all"])
    error_message = "Default egress must deny ALL protocols"
  }
}
