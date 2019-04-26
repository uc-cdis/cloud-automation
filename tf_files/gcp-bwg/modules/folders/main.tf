# Top-level folder under an organization.
resource "google_folder" "department" {
  count = "${var.create_folder ? 1 : 0}" 
  display_name = "${var.display_name}"
  parent       = "${var.parent_folder}"
}
