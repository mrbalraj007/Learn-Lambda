#!/usr/bin/env bash
set -euo pipefail

export AWS_PAGER=""
command -v aws >/dev/null 2>&1 || { echo "aws CLI is required"; exit 1; }
command -v jq  >/dev/null 2>&1 || { echo "jq is required"; exit 1; }

# Resolve account "name" (alias) for filenames; fallback to account ID
acct_alias="$(aws iam list-account-aliases --query 'AccountAliases[0]' --output text 2>/dev/null || true)"
if [ -z "${acct_alias}" ] || [ "${acct_alias}" = "None" ]; then
  acct_alias="$(aws sts get-caller-identity --query 'Account' --output text)"
fi

ts="$(date +%Y%m%d-%H%M%S)"
instances_csv="ec2-instance-tags_${acct_alias}_${ts}.csv"
volumes_csv="ebs-volume-tags_${acct_alias}_${ts}.csv"

# Use only the configured/selected region
region="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
if [ -z "${region}" ]; then
  region="$(aws configure get region || true)"
fi
[ -n "${region}" ] || { echo "No region configured. Set AWS_REGION or run 'aws configure'."; exit 1; }

# CSV headers
# Create/empty EC2 CSV; header will be written dynamically after discovering tag keys
: > "${instances_csv}"
echo 'Region,VolumeId,VolumeName,VolumeType,SizeGiB,IOPS,Throughput,CreateTime,AvailabilityZone,AttachedInstanceIds,AttachedDevices,TagKey,TagValue' > "${volumes_csv}"

echo "Processing ${region}..."
export REGION="${region}"

# ----- EC2: one row per instance; dynamic tag columns -----
if json_inst="$(aws ec2 describe-instances --region "${region}" --output json 2>/dev/null)"; then
  # Unique EC2 tag keys across all instances (sorted)
  ec2_keys_json="$(echo "${json_inst}" | jq -c '
    (.Reservations // []) | map(.Instances) | add // [] 
    | map(.Tags // []) | add // []
    | map(.Key) | unique | sort
  ')"

  # Build EC2 header dynamically
  header_line="$(jq -r --argjson keys "${ec2_keys_json:-[]}" '
    ["Region","InstanceId","InstanceName","InstanceType","PrivateIp","PublicIp","VpcId","SubnetId","SecurityGroupIds","LaunchTime","AvailabilityZone"] + $keys
    | @csv
  ' <<< '{}')"
  echo "${header_line}" > "${instances_csv}"

  # Write EC2 rows (tag values aligned to tag columns)
  echo "${json_inst}" | jq -r --arg region "${region}" --argjson keys "${ec2_keys_json:-[]}" '
    def name_from_tags($tags):
      ($tags // [] | map(select(.Key=="Name") | .Value) | first) // "";
    (.Reservations // []) | map(.Instances) | add // [] | .[] as $i
    | ($i.SecurityGroups // []) | map(.GroupId) | join("|") as $sgs
    | ( [ $region,
          $i.InstanceId,
          name_from_tags($i.Tags),
          ($i.InstanceType // ""),
          ($i.PrivateIpAddress // ""),
          ($i.PublicIpAddress // ""),
          ($i.VpcId // ""),
          ($i.SubnetId // ""),
          $sgs,
          ($i.LaunchTime // ""),
          ($i.Placement.AvailabilityZone // "")
        ]
        +
        ( $keys | map( . as $k
            | (($i.Tags // []) | map(select(.Key==$k) | .Value) | first) // "" ) )
      )
    | @csv
  ' >> "${instances_csv}"
else
  # If instances call fails, still emit base header without tag columns
  echo 'Region,InstanceId,InstanceName,InstanceType,PrivateIp,PublicIp,VpcId,SubnetId,SecurityGroupIds,LaunchTime,AvailabilityZone' > "${instances_csv}"
  echo "Warn: failed to describe instances in ${region}" >&2
fi

# ----- EBS: include attachments (unchanged) -----
if json_vol="$(aws ec2 describe-volumes --region "${region}" --output json 2>/dev/null)"; then
  # Write EBS rows
  echo "${json_vol}" | jq -r '
    def name_from_tags($tags):
      ($tags // [] | map(select(.Key=="Name") | .Value) | first) // "";
    (.Volumes // []) | .[] as $v
    | ($v.Attachments // []) as $atts
    | $atts | map(.InstanceId) | unique | join("|") as $insts
    | $atts | map(.Device) | join("|") as $devs
    | ($v.Tags // []) as $tags
    | if ($tags|length) > 0 then
        $tags[] | [env.REGION,
                   $v.VolumeId,
                   (name_from_tags($v.Tags)),
                   $v.VolumeType,
                   ($v.Size // null),
                   ($v.Iops // null),
                   ($v.Throughput // null),
                   $v.CreateTime,
                   $v.AvailabilityZone,
                   $insts,
                   $devs,
                   (.Key // ""),
                   (.Value // "")]
      else
        [env.REGION,
         $v.VolumeId,
         (name_from_tags($v.Tags)),
         $v.VolumeType,
         ($v.Size // null),
         ($v.Iops // null),
         ($v.Throughput // null),
         $v.CreateTime,
         $v.AvailabilityZone,
         $insts,
         $devs,
         "",
         ""]
      end
    | @csv
  ' >> "${volumes_csv}"
else
  # If describe-volumes failed, still create an EBS header
  echo 'Region,VolumeId,VolumeName,VolumeType,SizeGiB,IOPS,Throughput,CreateTime,AvailabilityZone,AttachedInstanceIds,AttachedDevices,TagKey,TagValue' > "${volumes_csv}"
  echo "Warn: failed to describe volumes in ${region}" >&2
fi

echo "Done."
echo "Instance tags: ${instances_csv}"
echo "Volume tags:   ${volumes_csv}"
