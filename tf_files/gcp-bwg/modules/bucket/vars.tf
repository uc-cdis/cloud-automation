variable "bucket_name" {
  type        = "list"
  description = "The name of the bucket."
}

variable "location" {
  default     = "us-central1"
  description = "The GCS location."
}

variable "project" {
  default     = ""
  description = "The project in which the resource belongs. If it is not provided, the provider project is used."
}

variable "force_destroy" {
  description = "When deleting a bucket, this boolean option will delete all contained objects."
  default     = "false"
}

variable "storage_class" {
  description = "The Storage Class of the new bucket. Supported values include: MULTI_REGIONAL, REGIONAL, NEARLINE, COLDLINE."
  default     = "REGIONAL"
}

# lifecycle_rule condition block
variable "age" {
  description = "Minimum age of an object in days to satisfy this condition."
  default     = "60"
}

variable "created_before" {
  description = "Creation date of an object in RFC 3339 (e.g. 2018-06-13) to satisfy this condition."
  default     = "2018-06-13"
}

variable "is_live" {
  description = "Relevant only for versioned objects. If true, this condition matches live objects, archived objects otherwise."
  default     = "false"
}

variable "matches_storage_class" {
  description = "Storage Class of objects to satisfy this condition. Supported values include: MULTI_REGIONAL, REGIONAL, NEARLINE, COLDLINE, STANDARD, DURABLE_REDUCED_AVAILABILITY."
  type        = "list"
  default     = ["REGIONAL"]
}

variable "num_newer_versions" {
  description = "Relevant only for versioned objects. The number of newer versions of an object to satisfy this condition."
  default     = "10"
}

# lifecycle_rule action block
variable "action_type" {
  description = "The type of the action of this Lifecycle Rule. Supported values include: Delete and SetStorageClass."
  default     = "SetStorageClass"
}

variable "action_storage_class" {
  description = "The target Storage Class of objects affected by this Lifecycle Rule. Supported values include: MULTI_REGIONAL, REGIONAL, NEARLINE, COLDLINE."
  default     = "NEARLINE"
}

# versioning block
variable "versioning_enabled" {
  description = "While set to true, versioning is fully enabled for this bucket."
  default     = "true"
}

# bucket ACL
variable "default_acl" {
  description = "Configure this ACL to be the default ACL."
  default     = "private"
}

variable "role_entity" {
  description = "List of role/entity pairs in the form ROLE:entity."
  type        = "list"
  default     = []
}

# Labels
variable "label-datacommons" {
  default = "commons1"
}

variable "label-department" {
  default = "ctds"
}

variable "label-env" {
  default = "development"
}

variable "label-sponsor" {
  default = "sponsor"
}
