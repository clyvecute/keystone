# scripts/setup-wif.ps1
# Automates the setup of Workload Identity Federation for Keystone on Windows / PowerShell

$ErrorActionPreference = "Stop"

function Log-Info($msg) { Write-Host "[WIF-SETUP] $msg" -ForegroundColor Cyan }
function Log-Success($msg) { Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Log-Warn($msg) { Write-Host "[WARNING] $msg" -ForegroundColor Yellow }
function Log-Err($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }

# 1. Check gcloud authentication
$account = (gcloud config get-value account 2>$null).Trim()
if (-not $account -or $account -eq "(unset)" -or -not ($account -like "*@*")) {
    Log-Err "No active gcloud account found. Please run 'gcloud auth login' first."
    exit 1
}

# 2. Configuration & Project check
$projectId = (gcloud config get-value project 2>$null).Trim()
if (-not $projectId -or $projectId -eq "(unset)") {
    Log-Err "No GCP project configured. Run 'gcloud config set project [PROJECT_ID]'"
    exit 1
}

# 3. Detect GitHub repo
$repoFull = "clyvecute/keystone"
try {
    $remoteUrl = (git remote get-url origin 2>$null).Trim()
    if ($remoteUrl -match 'github\.com[:/](.+?)(?:\.git)?$') {
        $repoFull = $Matches[1]
    }
} catch {
    Log-Warn "Could not detect GitHub repository from git remote. Using default: $repoFull"
}

$poolName = "keystone-pool"
$providerName = "keystone-github"
$saName = "keystone-github-actions"
$saEmail = "${saName}@${projectId}.iam.gserviceaccount.com"

Log-Info "Starting Workload Identity Federation setup for Project: $projectId"
Log-Info "Authenticated Account: $account"
Log-Info "Target Repository: $repoFull"

# 4. Enable Required APIs
Log-Info "Enabling IAM and Resource Manager APIs..."
gcloud services enable `
    iam.googleapis.com `
    iamcredentials.googleapis.com `
    cloudresourcemanager.googleapis.com `
    --project=$projectId

# 5. Create Service Account
Log-Info "Creating Service Account: $saName..."
$saExists = $false
try {
    $null = gcloud iam service-accounts describe $saEmail --project=$projectId 2>&1
    if ($LASTEXITCODE -eq 0) { $saExists = $true }
} catch {
    $saExists = $false
}

if ($saExists) {
    Log-Warn "Service account already exists."
} else {
    gcloud iam service-accounts create $saName `
        --display-name="Keystone GitHub Actions SA" `
        --project=$projectId
    Log-Success "Service account created."
}

# 6. Create Workload Identity Pool
Log-Info "Creating Workload Identity Pool: $poolName..."
$poolExists = $false
try {
    $null = gcloud iam workload-identity-pools describe $poolName --location="global" --project=$projectId 2>&1
    if ($LASTEXITCODE -eq 0) { $poolExists = $true }
} catch {
    $poolExists = $false
}

if ($poolExists) {
    Log-Warn "Workload identity pool already exists."
} else {
    gcloud iam workload-identity-pools create $poolName `
        --location="global" `
        --display-name="Keystone Identity Pool" `
        --project=$projectId
    Log-Success "Pool created."
}

# 7. Get Pool Full ID
$poolId = (gcloud iam workload-identity-pools describe $poolName `
    --location="global" `
    --format="value(name)" `
    --project=$projectId).Trim()

# 8. Create Workload Identity Provider
Log-Info "Creating OIDC Provider: $providerName..."
$providerExists = $false
try {
    $null = gcloud iam workload-identity-pools providers describe $providerName `
        --location="global" `
        --workload-identity-pool=$poolName `
        --project=$projectId 2>&1
    if ($LASTEXITCODE -eq 0) { $providerExists = $true }
} catch {
    $providerExists = $false
}

if ($providerExists) {
    Log-Warn "Provider already exists."
} else {
    gcloud iam workload-identity-pools providers create-oidc $providerName `
        --location="global" `
        --workload-identity-pool=$poolName `
        --display-name="Keystone GitHub Provider" `
        --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" `
        --attribute-condition="assertion.repository=='$repoFull'" `
        --issuer-uri="https://token.actions.githubusercontent.com" `
        --project=$projectId
    Log-Success "Provider created."
}

# 9. Bind Service Account to GitHub Repo
Log-Info "Binding Service Account to Repository: $repoFull..."
gcloud iam service-accounts add-iam-policy-binding $saEmail `
    --project=$projectId `
    --role="roles/iam.workloadIdentityUser" `
    --member="principalSet://iam.googleapis.com/${poolId}/attribute.repository/${repoFull}"

# 10. Grant Project-Level Permissions to SA
Log-Info "Granting permissions to Service Account..."
$roles = @(
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/run.admin",
    "roles/binaryauthorization.policyEditor",
    "roles/cloudsql.admin",
    "roles/cloudkms.admin",
    "roles/storage.admin",
    "roles/monitoring.admin",
    "roles/logging.admin",
    "roles/secretmanager.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/iam.serviceAccountUser"
)

foreach ($role in $roles) {
    Log-Info "Adding role: $role"
    gcloud projects add-iam-policy-binding $projectId `
        --member="serviceAccount:$saEmail" `
        --role=$role `
        --condition=None > $null
}

# 11. Output Results
$providerId = (gcloud iam workload-identity-pools providers describe $providerName `
    --location="global" `
    --workload-identity-pool=$poolName `
    --format="value(name)" `
    --project=$projectId).Trim()

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "  WORKLOAD IDENTITY FEDERATION SETUP COMPLETE!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "`nAdd the following secrets to your GitHub repository:"
Write-Host "Settings > Secrets and variables > Actions > New repository secret`n"
Write-Host "  WIF_PROVIDER:          $providerId" -ForegroundColor Yellow
Write-Host "  WIF_SERVICE_ACCOUNT:   $saEmail" -ForegroundColor Yellow
Write-Host "  GCP_PROJECT_ID:        $projectId" -ForegroundColor Yellow
Write-Host "`nNote: Ensure your repo is set to '$repoFull'." -ForegroundColor Cyan
Write-Host "If it's different, update the IAM binding manually.`n"
