terraform output -json | Out-File outputs.json
$outputs = Get-Content outputs.json -Raw | ConvertFrom-Json

"[web_servers]`n" | Out-File inventory.ini -Encoding UTF8
foreach ($ip in $outputs.asg_public_ips.value) {  # Public pour SSH
    "$ip ansible_user=ec2-user" | Add-Content inventory.ini
}

@"

[all:vars]
ansible_ssh_private_key_file=`$env:USERPROFILE/.ssh/id_rsa
"@ | Add-Content inventory.ini

Get-Content inventory.ini
