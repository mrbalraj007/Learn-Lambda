How do I check if anything uses IMDSv1?
Check for direct metadata calls

Windows:

```PowerShell
Get-ChildItem C:\ -Recurse -Include *.ps1,*.bat,*.cmd,*.py,*.config `
-ErrorAction SilentlyContinue |
Select-String "169.254.169.254"
```
Linux:
```Shell
grep -R "169.254.169.254" /opt /usr/local /home 2>/dev/null
```

Anything found should be reviewed.