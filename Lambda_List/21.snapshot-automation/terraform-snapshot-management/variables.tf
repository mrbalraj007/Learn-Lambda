variable "retention_days" {
  type    = number
  default = 90
  description = "Number of days to retain a snapshot before it's considered stale"
}
