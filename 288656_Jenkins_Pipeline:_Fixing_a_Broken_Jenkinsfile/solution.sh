#!/bin/bash

set -euo pipefail

LAB_DIR="/home/user/nexaflow-lab"
JENKINSFILE="${LAB_DIR}/Jenkinsfile"
JENKINS_CLI="/usr/local/bin/judge/jenkins-cli.jar"
JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASS="admin"
JOB_NAME="payment-reconciler"

function jenkins_cli() {
    java -jar "$JENKINS_CLI" -s "$JENKINS_URL" -auth "${JENKINS_USER}:${JENKINS_PASS}" "$@"
}

function fix_jenkinsfile() {
    cat > "$JENKINSFILE" << 'EOF'
pipeline {
    agent any

    environment {
        APP_NAME = "payment-reconciler"
        BUILD_VERSION = "1.0.${BUILD_NUMBER}"
        DEPLOY_ENV = "staging"
    }

    stages {
        stage("Checkout") {
            steps {
                echo "Checking out source code for ${APP_NAME} version ${BUILD_VERSION}"
            }
        }

        stage("Validate") {
            steps {
                echo "Running validation checks for ${APP_NAME}"
            }
        }

        stage("Build") {
            steps {
                echo "Building ${APP_NAME} version ${BUILD_VERSION}"
                sh "echo Build completed successfully"
            }
        }

        stage("Deploy") {
            steps {
                echo "Deploying ${APP_NAME} to ${DEPLOY_ENV}"
                sh "echo Deployment to ${DEPLOY_ENV} complete"
            }
        }
    }

    post {
        always {
            echo "Pipeline finished. Cleaning up workspace."
        }
    }
}
EOF
}

function update_jenkins_job() {
    echo "Pushing fixed Jenkinsfile to Jenkins job '${JOB_NAME}'..."

    local jenkinsfile_content
    jenkinsfile_content=$(cat "$JENKINSFILE")

    local escaped_content
    escaped_content=$(printf '%s' "$jenkinsfile_content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')

    local job_config
    job_config=$(cat << EOF
<?xml version='1.1' encoding='UTF-8'?>
<org.jenkinsci.plugins.workflow.job.WorkflowJob plugin="workflow-job">
  <description>NexaFlow payment-reconciler CI pipeline</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script>${escaped_content}</script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</org.jenkinsci.plugins.workflow.job.WorkflowJob>
EOF
)

    echo "$job_config" | jenkins_cli update-job "$JOB_NAME"
    echo "Job '${JOB_NAME}' updated successfully."
}

function show_summary() {
    echo ""
    echo "=========================================="
    echo "FIXES APPLIED"
    echo "=========================================="
    echo ""
    echo "Fix 1: Agent declaration"
    echo "  Before: agent none"
    echo "  After:  agent any"
    echo ""
    echo "Fix 2: Missing environment variable"
    echo "  Before: DEPLOY_ENV not defined"
    echo "  After:  DEPLOY_ENV = staging"
    echo ""
    echo "Fix 3: Missing steps block"
    echo "  Before: Validate stage had no steps block"
    echo "  After:  echo wrapped inside steps block"
    echo ""
    echo "Fix 4: Invalid post condition"
    echo "  Before: always_run"
    echo "  After:  always"
    echo ""
    echo "=========================================="
    echo "JENKINSFILE READY"
    echo "=========================================="
    echo ""
    echo "Trigger a build of the ${JOB_NAME} job"
    echo "from the Jenkins UI to verify the fix."
    echo ""
}

function main() {
    echo "=========================================="
    echo "NEXAFLOW JENKINS PIPELINE: APPLYING FIXES"
    echo "=========================================="
    echo ""
    echo "Updating Jenkinsfile at: $JENKINSFILE"
    echo ""

    fix_jenkinsfile
    update_jenkins_job
    show_summary
}

main