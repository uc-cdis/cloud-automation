# Top-level folder under an organization.
resource "google_folder" "department" {
  display_name = "${var.display_name}"
  parent     = "${var.parent_folder}"
}
