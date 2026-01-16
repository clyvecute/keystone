package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

// PreflightCheck represents a single validation check
type PreflightCheck struct {
	Name        string
	Description string
	Required    bool
	Check       func() CheckResult
}

// CheckResult represents the result of a preflight check
type CheckResult struct {
	Passed  bool
	Message string
	Details string
}

// PreflightReport contains all check results
type PreflightReport struct {
	Timestamp    time.Time
	Environment  string
	TotalChecks  int
	Passed       int
	Failed       int
	Warnings     int
	Checks       []CheckResultWithName
	CanDeploy    bool
}

// CheckResultWithName combines check name with result
type CheckResultWithName struct {
	Name     string
	Required bool
	Result   CheckResult
}

var (
	environment = getEnv("APP_ENV", "dev")
	projectID   = getEnv("GCP_PROJECT_ID", "")
)

func main() {
	fmt.Println("🚀 Keystone Preflight Check")
	fmt.Printf("Environment: %s\n", environment)
	fmt.Printf("Timestamp: %s\n\n", time.Now().Format(time.RFC3339))

	checks := []PreflightCheck{
		{
			Name:        "gcloud-installed",
			Description: "gcloud CLI is installed",
			Required:    true,
			Check:       checkGcloudInstalled,
		},
		{
			Name:        "gcloud-authenticated",
			Description: "gcloud is authenticated",
			Required:    true,
			Check:       checkGcloudAuthenticated,
		},
		{
			Name:        "terraform-installed",
			Description: "Terraform is installed",
			Required:    true,
			Check:       checkTerraformInstalled,
		},
		{
			Name:        "terraform-version",
			Description: "Terraform version >= 1.5.0",
			Required:    true,
			Check:       checkTerraformVersion,
		},
		{
			Name:        "project-id-set",
			Description: "GCP_PROJECT_ID is set",
			Required:    true,
			Check:       checkProjectIDSet,
		},
		{
			Name:        "required-apis",
			Description: "Required GCP APIs are enabled",
			Required:    true,
			Check:       checkRequiredAPIs,
		},
		{
			Name:        "state-bucket-exists",
			Description: "Terraform state bucket exists",
			Required:    true,
			Check:       checkStateBucketExists,
		},
		{
			Name:        "backup-bucket-exists",
			Description: "Backup bucket exists",
			Required:    false,
			Check:       checkBackupBucketExists,
		},
		{
			Name:        "env-file-exists",
			Description: ".env file is configured",
			Required:    false,
			Check:       checkEnvFileExists,
		},
		{
			Name:        "terraform-formatted",
			Description: "Terraform files are formatted",
			Required:    false,
			Check:       checkTerraformFormatted,
		},
	}

	report := runChecks(checks)
	printReport(report)

	// Output JSON report if requested
	if os.Getenv("PREFLIGHT_JSON") == "true" {
		outputJSON(report)
	}

	// Exit with appropriate code
	if !report.CanDeploy {
		os.Exit(1)
	}
}

func runChecks(checks []PreflightCheck) PreflightReport {
	report := PreflightReport{
		Timestamp:   time.Now(),
		Environment: environment,
		TotalChecks: len(checks),
		Checks:      make([]CheckResultWithName, 0, len(checks)),
	}

	for _, check := range checks {
		result := check.Check()
		
		checkResult := CheckResultWithName{
			Name:     check.Name,
			Required: check.Required,
			Result:   result,
		}
		
		report.Checks = append(report.Checks, checkResult)

		if result.Passed {
			report.Passed++
		} else {
			if check.Required {
				report.Failed++
			} else {
				report.Warnings++
			}
		}
	}

	// Can deploy if all required checks pass
	report.CanDeploy = report.Failed == 0

	return report
}

func printReport(report PreflightReport) {
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println("Preflight Check Results")
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	for _, check := range report.Checks {
		status := "✓"
		color := "\033[32m" // Green
		
		if !check.Result.Passed {
			if check.Required {
				status = "✗"
				color = "\033[31m" // Red
			} else {
				status = "⚠"
				color = "\033[33m" // Yellow
			}
		}

		fmt.Printf("%s%s\033[0m %s\n", color, status, check.Result.Message)
		if check.Result.Details != "" {
			fmt.Printf("  → %s\n", check.Result.Details)
		}
	}

	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Printf("Total: %d | Passed: %d | Failed: %d | Warnings: %d\n",
		report.TotalChecks, report.Passed, report.Failed, report.Warnings)
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	if report.CanDeploy {
		fmt.Println("\033[32m✓ Ready to deploy\033[0m")
	} else {
		fmt.Println("\033[31m✗ Not ready to deploy - fix required checks\033[0m")
	}
}

func outputJSON(report PreflightReport) {
	data, err := json.MarshalIndent(report, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error generating JSON: %v\n", err)
		return
	}
	
	filename := fmt.Sprintf("preflight-report-%s.json", time.Now().Format("20060102-150405"))
	if err := os.WriteFile(filename, data, 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Error writing JSON: %v\n", err)
		return
	}
	
	fmt.Printf("\n📄 Report saved to: %s\n", filename)
}

// Check functions

func checkGcloudInstalled() CheckResult {
	_, err := exec.LookPath("gcloud")
	if err != nil {
		return CheckResult{
			Passed:  false,
			Message: "gcloud CLI not found",
			Details: "Install from: https://cloud.google.com/sdk/docs/install",
		}
	}
	return CheckResult{
		Passed:  true,
		Message: "gcloud CLI is installed",
	}
}

func checkGcloudAuthenticated() CheckResult {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "gcloud", "auth", "list", "--filter=status:ACTIVE", "--format=value(account)")
	output, err := cmd.Output()
	
	if err != nil || len(strings.TrimSpace(string(output))) == 0 {
		return CheckResult{
			Passed:  false,
			Message: "gcloud not authenticated",
			Details: "Run: gcloud auth login",
		}
	}
	
	account := strings.TrimSpace(string(output))
	return CheckResult{
		Passed:  true,
		Message: "gcloud is authenticated",
		Details: fmt.Sprintf("Active account: %s", account),
	}
}

func checkTerraformInstalled() CheckResult {
	_, err := exec.LookPath("terraform")
	if err != nil {
		return CheckResult{
			Passed:  false,
			Message: "Terraform not found",
			Details: "Install from: https://www.terraform.io/downloads",
		}
	}
	return CheckResult{
		Passed:  true,
		Message: "Terraform is installed",
	}
}

func checkTerraformVersion() CheckResult {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "terraform", "version", "-json")
	output, err := cmd.Output()
	
	if err != nil {
		return CheckResult{
			Passed:  false,
			Message: "Could not check Terraform version",
			Details: err.Error(),
		}
	}

	var versionInfo struct {
		TerraformVersion string `json:"terraform_version"`
	}
	
	if err := json.Unmarshal(output, &versionInfo); err != nil {
		return CheckResult{
			Passed:  false,
			Message: "Could not parse Terraform version",
		}
	}

	// Simple version check (should be >= 1.5.0)
	if strings.HasPrefix(versionInfo.TerraformVersion, "1.5") ||
		strings.HasPrefix(versionInfo.TerraformVersion, "1.6") ||
		strings.HasPrefix(versionInfo.TerraformVersion, "1.7") ||
		strings.HasPrefix(versionInfo.TerraformVersion, "1.8") ||
		strings.HasPrefix(versionInfo.TerraformVersion, "1.9") {
		return CheckResult{
			Passed:  true,
			Message: "Terraform version is compatible",
			Details: fmt.Sprintf("Version: %s", versionInfo.TerraformVersion),
		}
	}

	return CheckResult{
		Passed:  false,
		Message: "Terraform version too old",
		Details: fmt.Sprintf("Found: %s, Required: >= 1.5.0", versionInfo.TerraformVersion),
	}
}

func checkProjectIDSet() CheckResult {
	if projectID == "" {
		return CheckResult{
			Passed:  false,
			Message: "GCP_PROJECT_ID not set",
			Details: "Set in .env or environment",
		}
	}
	return CheckResult{
		Passed:  true,
		Message: "GCP_PROJECT_ID is set",
		Details: fmt.Sprintf("Project: %s", projectID),
	}
}

func checkRequiredAPIs() CheckResult {
	if projectID == "" {
		return CheckResult{
			Passed:  false,
			Message: "Cannot check APIs - project ID not set",
		}
	}

	requiredAPIs := []string{
		"run.googleapis.com",
		"sqladmin.googleapis.com",
		"storage-api.googleapis.com",
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "gcloud", "services", "list",
		"--enabled", "--project="+projectID, "--format=value(name)")
	output, err := cmd.Output()
	
	if err != nil {
		return CheckResult{
			Passed:  false,
			Message: "Could not check enabled APIs",
			Details: "Ensure you have permission to list services",
		}
	}

	enabledAPIs := strings.Split(string(output), "\n")
	enabledMap := make(map[string]bool)
	for _, api := range enabledAPIs {
		enabledMap[strings.TrimSpace(api)] = true
	}

	missing := []string{}
	for _, api := range requiredAPIs {
		if !enabledMap[api] {
			missing = append(missing, api)
		}
	}

	if len(missing) > 0 {
		return CheckResult{
			Passed:  false,
			Message: "Required APIs not enabled",
			Details: fmt.Sprintf("Missing: %s", strings.Join(missing, ", ")),
		}
	}

	return CheckResult{
		Passed:  true,
		Message: "Required APIs are enabled",
	}
}

func checkStateBucketExists() CheckResult {
	if projectID == "" {
		return CheckResult{
			Passed:  false,
			Message: "Cannot check state bucket - project ID not set",
		}
	}

	bucketName := fmt.Sprintf("keystone-terraform-state-%s", environment)
	
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "gsutil", "ls", "-b", "gs://"+bucketName)
	err := cmd.Run()
	
	if err != nil {
		return CheckResult{
			Passed:  false,
			Message: "Terraform state bucket does not exist",
			Details: fmt.Sprintf("Create with: gsutil mb gs://%s", bucketName),
		}
	}

	return CheckResult{
		Passed:  true,
		Message: "Terraform state bucket exists",
		Details: fmt.Sprintf("Bucket: gs://%s", bucketName),
	}
}

func checkBackupBucketExists() CheckResult {
	bucketName := "keystone-backups"
	
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "gsutil", "ls", "-b", "gs://"+bucketName)
	err := cmd.Run()
	
	if err != nil {
		return CheckResult{
			Passed:  false,
			Message: "Backup bucket does not exist",
			Details: fmt.Sprintf("Create with: gsutil mb gs://%s", bucketName),
		}
	}

	return CheckResult{
		Passed:  true,
		Message: "Backup bucket exists",
	}
}

func checkEnvFileExists() CheckResult {
	if _, err := os.Stat(".env"); os.IsNotExist(err) {
		return CheckResult{
			Passed:  false,
			Message: ".env file not found",
			Details: "Copy from .env.example and configure",
		}
	}
	return CheckResult{
		Passed:  true,
		Message: ".env file exists",
	}
}

func checkTerraformFormatted() CheckResult {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "terraform", "fmt", "-check", "-recursive", "terraform/")
	err := cmd.Run()
	
	if err != nil {
		return CheckResult{
			Passed:  false,
			Message: "Terraform files not formatted",
			Details: "Run: terraform fmt -recursive terraform/",
		}
	}

	return CheckResult{
		Passed:  true,
		Message: "Terraform files are formatted",
	}
}

// Helper functions

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
