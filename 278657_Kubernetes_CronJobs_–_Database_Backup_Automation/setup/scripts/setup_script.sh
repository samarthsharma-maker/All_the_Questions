#!/bin/bash

set -euo pipefail

BASE_DIR="/home/user/datastore-lab"
NAMESPACE="datastore-prod"

NS_FILE="${BASE_DIR}/namespace.yaml"
CRONJOB_FILE="${BASE_DIR}/backup-cronjob.yaml"

function create_base_directory() {
    mkdir -p "${BASE_DIR}"
}

function create_namespace_yaml() {
    cat > "${NS_FILE}" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: datastore-prod
  labels:
    environment: production
    team: data-engineering
EOF
}

function create_broken_cronjob_yaml() {
    cat > "${CRONJOB_FILE}" <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: database-backup
  namespace: datastore-prod
  labels:
    app: database-backup
    type: maintenance
spec:
  # Misconfiguration 1: Invalid cron schedule syntax
  schedule: "0 2 * * *"
  
  # Misconfiguration 2: Missing successfulJobsHistoryLimit and failedJobsHistoryLimit
  # This will cause unlimited job history buildup
  
  # Misconfiguration 3: No concurrencyPolicy set
  # Could cause concurrent backup jobs to run simultaneously
  
  jobTemplate:
    spec:
      # Misconfiguration 4: No backoffLimit set
      # Jobs will retry indefinitely on failure
      
      template:
        metadata:
          labels:
            app: database-backup
        spec:
          # Misconfiguration 5: Wrong restartPolicy
          restartPolicy: Always
          
          containers:
          - name: backup
            image: postgres:15-alpine
            command:
            - /bin/sh
            - -c
            - |
              echo "Starting database backup at $(date)"
              echo "Connecting to database..."
              echo "Backing up tables..."
              sleep 5
              echo "Backup completed successfully at $(date)"
            
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


function finalize_lab_setup() {
    chown -R user:user "${BASE_DIR}" 2>/dev/null || true

    echo
    echo "=========================================="
    echo "DATABASE BACKUP CRONJOB LAB"
    echo "=========================================="
    echo
    echo "Lab manifests created:"
    echo "  ${NS_FILE}"
    echo "  ${CRONJOB_FILE}"
    echo
    echo "Apply the lab with:"
    echo "  kubectl apply -f ${BASE_DIR}"
    echo
    echo "=========================================="
    echo "ISSUES TO FIX:"
    echo "=========================================="
    echo
    echo "The CronJob has several misconfigurations:"
    echo "  1. Invalid cron schedule (needs timezone specification)"
    echo "  2. Missing job history limits (will accumulate jobs)"
    echo "  3. No concurrency policy (backups could overlap)"
    echo "  4. Missing backoff limit (infinite retries on failure)"
    echo "  5. Wrong restart policy for Jobs (should be OnFailure or Never)"
    echo
    echo "Learner tasks:"
    echo "  1. Fix cron schedule to run at 2 AM UTC daily"
    echo "  2. Set successfulJobsHistoryLimit: 3"
    echo "  3. Set failedJobsHistoryLimit: 1"
    echo "  4. Set concurrencyPolicy: Forbid"
    echo "  5. Set backoffLimit: 3"
    echo "  6. Change restartPolicy to OnFailure"
    echo
    echo "Expected behavior after fixes:"
    echo "  - Backup runs every day at 2 AM UTC"
    echo "  - Only last 3 successful jobs kept in history"
    echo "  - Only last 1 failed job kept in history"
    echo "  - No concurrent backup jobs allowed"
    echo "  - Maximum 3 retries on failure"
    echo "  - Pod restarts only on failure"
    echo
    echo "=========================================="
}

# --------------------------------------------------
# Main
# --------------------------------------------------
function main() {
    create_base_directory
    create_namespace_yaml
    create_broken_cronjob_yaml
    finalize_lab_setup
}

main