resource "aws_iam_saml_provider" "uchicagoidp" {
  name                   = "UChicagoIdP"
  saml_metadata_document = file("${path.module}/metadata/saml-metadata.xml")
}