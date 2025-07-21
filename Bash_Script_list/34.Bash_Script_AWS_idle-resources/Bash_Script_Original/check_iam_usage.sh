#!/bin/bash

source ./utils.sh

ACCOUNT_ID=$(get_account_id)
REGION=$(aws configure get region)

log_info "Checking IAM users, roles, and policies"
echo "------------------------------------------"

# List IAM users
users=$(aws iam list-users --query 'Users[*].UserName' --output text)
if [ -z "$users" ]; then
  log_warn "No IAM users found in account $ACCOUNT_ID."
else
  log_info "✅ IAM Users:"
  for user in $users; do
    log_success "👤 User: $user"
  done
fi

# List IAM roles
roles=$(aws iam list-roles --query 'Roles[*].RoleName' --output text)
if [ -z "$roles" ]; then
  log_warn "No IAM roles found in account $ACCOUNT_ID."
else
  log_info "✅ IAM Roles:"
  for role in $roles; do
    log_success "🛡️ Role: $role"
  done
fi

# List inline and managed policies attached to users
log_info "🔍 Checking IAM policies attached to users"
for user in $users; do
  echo
  log_info "User: $user"

  inline_policies=$(aws iam list-user-policies --user-name "$user" --query 'PolicyNames' --output text)
  if [ -n "$inline_policies" ]; then
    log_warn "📎 Inline Policies for $user: $inline_policies"
  fi

  attached_policies=$(aws iam list-attached-user-policies --user-name "$user" --query 'AttachedPolicies[*].PolicyName' --output text)
  if [ -n "$attached_policies" ]; then
    log_success "🔗 Managed Policies for $user: $attached_policies"
  fi
done

echo
log_info "👉 Tip: Review IAM permissions regularly. Avoid inline policies when possible."
log_info "🔗 IAM Console: https://console.aws.amazon.com/iam/home"
