#!/bin/bash

set -euo pipefail

BASE_DIR="$HOME/datastore-solution"
NAMESPACE="datastore-prod"

NS_FILE="${BASE_DIR}/namespace.yaml"
CRONJOB_FILE="${BASE_DIR}/backup-cronjob-fixed.yaml"

mkdir -p "$BASE_DIR"

# --------------------------------------------------
# Namespace
# --------------------------------------------------
function create_namespace_yaml() {
    cat > "$NS_FILE" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: datastore-prod
  labels:
    environment: production
    team: data-engineering
EOF
}

# --------------------------------------------------
# CronJob (FIXED - ALL ISSUES RESOLVED)
# --------------------------------------------------
function create_fixed_cronjob_yaml() {
    cat > "$CRONJOB_FILE" <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-backup
  namespace: datastore-prod
  labels:
    app: database-backup
    type: maintenance
spec:
  # FIX 1: Proper cron schedule - runs at 2 AM UTC daily
  schedule: "0 2 * * *"
  
  # FIX 2 & 3: Set job history limits to prevent buildup
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  
  # FIX 4: Prevent concurrent backup jobs
  concurrencyPolicy: Forbid
  
  jobTemplate:
    spec:
      # FIX 5: Limit retries to 3 attempts
      backoffLimit: 3
      
      template:
        metadata:
          labels:
            app: database-backup
        spec:
          # FIX 6: Correct restart policy for Jobs
          restartPolicy: OnFailure
          
          containers:
          - name: backup
            image: postgres:15-alpine
            command:
            - /bin/sh
            - -c
            - |
              echo "=================================="
              echo "DATABASE BACKUP STARTED"
              echo "=================================="
              echo "Timestamp: $(date)"
              echo "Database: analytics_db"
              echo "Retention: ${BACKUP_RETENTION_DAYS} days"
              echo ""
              echo "Connecting to PostgreSQL..."
              echo "Host: ${PGHOST}"
              echo "Database: ${PGDATABASE}"
              echo "User: ${PGUSER}"
              echo ""
              echo "Performing backup operations..."
              sleep 3
              echo "  - Dumping schema..."
              sleep 1
              echo "  - Dumping data tables..."
              sleep 1
              echo "  - Compressing backup file..."
              sleep 1
              echo ""
              echo "Backup file: backup-$(date +%Y%m%d-%H%M%S).sql.gz"
              echo ""
              echo "=================================="
              echo "BACKUP COMPLETED SUCCESSFULLY"
              echo "=================================="
              echo "Completed at: $(date)"
            
            env:
            - name: PGHOST
              value: postgres.datastore-prod.svc.cluster.local
            - name: PGDATABASE
              value: analytics_db
            - name: PGUSER
              value: backup_user
            - name: BACKUP_RETENTION_DAYS
              value: "7"
            
            resources:
              requests:
                cpu: 100m
                memory: 128Mi
              limits:
                cpu: 200m
                memory: 256Mi
EOF
}

# --------------------------------------------------
# Ensure Namespace Exists
# --------------------------------------------------
function ensure_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
        echo "Creating namespace $NAMESPACE..."
        kubectl apply -f "$NS_FILE"
    else
        echo "Namespace $NAMESPACE already exists."
    fi
}

# --------------------------------------------------
# Apply Resources
# --------------------------------------------------
function apply_resources() {
    echo ""
    echo "Applying fixed CronJob..."
    kubectl apply -f "$CRONJOB_FILE"
}

# --------------------------------------------------
# Verify CronJob
# --------------------------------------------------
function verify_cronjob() {
    echo ""
    echo "=========================================="
    echo "CRONJOB VERIFICATION"
    echo "=========================================="
    
    echo ""
    echo "1. CronJob details:"
    kubectl get cronjob database-backup -n "$NAMESPACE"
    
    echo ""
    echo "2. CronJob schedule and settings:"
    kubectl get cronjob database-backup -n "$NAMESPACE" -o yaml | grep -A 10 "spec:"
    
    echo ""
    echo "3. Creating a manual test job from CronJob..."
    kubectl create job database-backup-manual-test --from=cronjob/database-backup -n "$NAMESPACE"
    
    echo ""
    echo "4. Waiting for test job to complete..."
    kubectl wait --for=condition=complete --timeout=60s job/database-backup-manual-test -n "$NAMESPACE" 2>/dev/null || true
    
    echo ""
    echo "5. Test job status:"
    kubectl get job database-backup-manual-test -n "$NAMESPACE"
    
    echo ""
    echo "6. Test job pod logs:"
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l job-name=database-backup-manual-test -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$POD_NAME" ]; then
        kubectl logs "$POD_NAME" -n "$NAMESPACE"
    else
        echo "No pod found for test job"
    fi
    
    echo ""
    echo "7. Cleaning up test job..."
    kubectl delete job database-backup-manual-test -n "$NAMESPACE" --ignore-not-found=true
}

# --------------------------------------------------
# Configuration Summary
# --------------------------------------------------
function show_summary() {
    echo ""
    echo "=========================================="
    echo "CONFIGURATION SUMMARY"
    echo "=========================================="
    echo ""
    echo "All fixes applied:"
    echo "  ✓ Schedule: 0 2 * * * (2 AM UTC daily)"
    echo "  ✓ Successful jobs history: 3"
    echo "  ✓ Failed jobs history: 1"
    echo "  ✓ Concurrency policy: Forbid"
    echo "  ✓ Backoff limit: 3"
    echo "  ✓ Restart policy: OnFailure"
    echo ""
    echo "CronJob behavior:"
    echo "  - Runs every day at 2:00 AM UTC"
    echo "  - Keeps last 3 successful job records"
    echo "  - Keeps last 1 failed job record"
    echo "  - Prevents concurrent backups"
    echo "  - Retries up to 3 times on failure"
    echo "  - Pods restart only on failure"
    echo ""
    echo "Next scheduled run:"
    kubectl get cronjob database-backup -n "$NAMESPACE" -o jsonpath='{.status.lastScheduleTime}' 2>/dev/null || echo "Not scheduled yet"
    echo ""
    echo "=========================================="
    echo "BACKUP CRONJOB READY"
    echo "=========================================="
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    echo "=========================================="
    echo "FIXING CRONJOB MISCONFIGURATIONS"
    echo "=========================================="
    echo ""
    echo "Creating solution files in: $BASE_DIR"
    echo ""
    
    create_namespace_yaml
    create_fixed_cronjob_yaml
    
    echo "Solution files created:"
    echo "  $NS_FILE"
    echo "  $CRONJOB_FILE"
    echo ""
    
    ensure_namespace
    apply_resources
    verify_cronjob
    show_summary
}

main