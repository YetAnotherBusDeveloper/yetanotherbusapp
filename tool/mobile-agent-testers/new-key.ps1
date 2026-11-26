# Run locally on Windows, never in CI. Generates/replaces ONLY the public PEM
# in the checkout; each private key gets a new owner-only directory in the profile.
$ErrorActionPreference = 'Stop'
$openssl = (Get-Command openssl -CommandType Application -ErrorAction Stop).Source
$dir = Join-Path $env:USERPROFILE ('.mobile-agent-testers\YABus-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$acl = Get-Acl $dir
$acl.SetAccessRuleProtection($true, $false)
$me = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($me, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
Set-Acl -Path $dir -AclObject $acl
$priv = Join-Path $dir 'private.pem'
& $openssl genpkey -quiet -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out $priv
if ($LASTEXITCODE) { throw 'RSA key generation failed' }
& $openssl pkey -in $priv -pubout -out (Join-Path $PSScriptRoot 'results_public.pem')
if ($LASTEXITCODE) { throw 'Public key export failed' }
Write-Host "Back up this private key securely (never add it to git or Actions): $priv"
