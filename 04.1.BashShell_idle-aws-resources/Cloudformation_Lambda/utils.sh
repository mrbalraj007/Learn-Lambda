################################################################## 
# Script for Common Shared Logic
################################################################## 

#!/bin/bash

get_account_id() {
  aws sts get-caller-identity --query Account --output text 2>/dev/null
}

log_info() {
  echo -e "ℹ️  $1"
}

log_warn() {
  echo -e "⚠️  $1"
}

log_success() {
  echo -e "✅ $1"
}

log_error() {
  echo -e "❌ $1"
}
