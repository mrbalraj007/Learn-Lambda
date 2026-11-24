# How to run `pre-Check-imds-all-EC2.sh` script.

- Run the following script in bash shell to report for all EC2
```sh
pre-Check-imds-all-EC2.sh
```

## How do I check if anything uses IMDSv1 inside the Operating System?
Check for direct metadata calls

### Windows:

```PowerShell
Get-ChildItem C:\ -Recurse -Include *.ps1,*.bat,*.cmd,*.py,*.config `
-ErrorAction SilentlyContinue |
Select-String "169.254.169.254"
```
### Linux:
```Shell
grep -R "169.254.169.254" /opt /usr/local /home 2>/dev/null
```

Anything found should be reviewed.


# Validate IMDS details from cloud console
```sh
aws ec2 describe-instances \
    --instance-ids i-06789b27b3ff0a8df i-0f2b8d6b8de6661b8 i-0ab5d348ca0a7fbcf i-05b48ec895ca52265 i-0f6694c8394d788e2 i-05cb8d90cc29835c0 i-0c8c56de7fd1fcfaa i-0012e25f81cd7163c i-0641272edbf24c22b i-0b2f620281c645a64 i-030c778ff1cb582f6 i-023a5d1bceb358059 i-01ee475d4c79fecfd i-05ea0a49e31cbe8c8 \
    --query 'Reservations[].Instances[].{InstanceId:InstanceId,Name:Tags[?Key==`Name`]|[0].Value,HttpTokens:MetadataOptions.HttpTokens}' \
    --output table
```

# Apply IMDSv2
```sh
aws ec2 modify-instance-metadata-options --instance-id i-030c778ff1cb582f6 --http-tokens required  
``