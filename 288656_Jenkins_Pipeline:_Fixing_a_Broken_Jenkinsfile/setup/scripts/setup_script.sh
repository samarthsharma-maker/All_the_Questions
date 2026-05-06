#!/bin/bash

set -euo pipefail

LAB_DIR="/home/user/nexaflow-lab"
JENKINS_CLI="/usr/local/bin/judge/jenkins-cli.jar"
JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASS="admin"
JOB_NAME="payment-reconciler"

mkdir -p "${LAB_DIR}"

function jenkins_cli() {
    java -jar "$JENKINS_CLI" -s "$JENKINS_URL" -auth "${JENKINS_USER}:${JENKINS_PASS}" "$@"
}

function wait_for_jenkins() {
    echo "Waiting for Jenkins to be ready..."
    local retries=30
    until curl -s -o /dev/null -w "%{http_code}" "${JENKINS_URL}/login" | grep -q "200"; do
        retries=$((retries - 1))
        if [ $retries -eq 0 ]; then
            echo "Jenkins did not become ready in time. Exiting."
            exit 1
        fi
        sleep 3
    done
    echo "Jenkins is ready."
}

function install_plugins() {
    echo "Installing required plugins..."
    jenkins_cli install-plugin workflow-job -restart || true
    jenkins_cli install-plugin workflow-cps -restart || true
    jenkins_cli install-plugin workflow-basic-steps -restart || true
    jenkins_cli install-plugin workflow-durable-task-step -restart || true
    jenkins_cli install-plugin pipeline-stage-step -restart || true

    echo "Waiting for Jenkins to restart after plugin installation..."
    sleep 15

    local retries=30
    until curl -s -o /dev/null -w "%{http_code}" "${JENKINS_URL}/login" | grep -q "200"; do
        retries=$((retries - 1))
        if [ $retries -eq 0 ]; then
            echo "Jenkins did not come back after restart. Exiting."
            exit 1
        fi
        sleep 5
    done
    echo "Jenkins is back and ready."
}

function create_broken_jenkinsfile() {
    cat > "${LAB_DIR}/Jenkinsfile" << 'EOF'
pipeline {
    agent none

    environment {
        APP_NAME = "payment-reconciler"
        BUILD_VERSION = "1.0.${BUILD_NUMBER}"
    }

    stages {
        stage("Checkout") {
            steps {
                echo "Checking out source code for ${APP_NAME} version ${BUILD_VERSION}"
            }
        }

        stage("Validate") {
            echo "Running validation checks for ${APP_NAME}"
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
        always_run {
            echo "Pipeline finished. Cleaning up workspace."
        }
    }
}
EOF
}

function create_jenkins_job() {
    echo "Creating Jenkins job '${JOB_NAME}'..."

    local jenkinsfile_content
    jenkinsfile_content=$(cat "${LAB_DIR}/Jenkinsfile")

    local escaped_content
    escaped_content=$(printf '%s' "$jenkinsfile_content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')

    # Use bash variable expansion in here-doc (handles special characters correctly, no sed needed)
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

    if jenkins_cli get-job "$JOB_NAME" &>/dev/null; then
        echo "Job '${JOB_NAME}' already exists. Updating..."
        echo "$job_config" | jenkins_cli update-job "$JOB_NAME"
    else
        echo "$job_config" | jenkins_cli create-job "$JOB_NAME"
    fi

    echo "Job '${JOB_NAME}' created successfully."
}

function finalize() {
    chown -R user:user "${LAB_DIR}" 2>/dev/null || true

    echo
    echo "=========================================="
    echo "NEXAFLOW JENKINS PIPELINE LAB: ENVIRONMENT READY"
    echo "=========================================="
    echo
    echo "Lab directory:  ${LAB_DIR}"
    echo "Jenkinsfile:    ${LAB_DIR}/Jenkinsfile"
    echo "Jenkins job:    ${JOB_NAME}"
    echo
    echo "Your task:"
    echo "  Inspect the Jenkinsfile, identify all issues,"
    echo "  fix them, and trigger a successful build from"
    echo "  the Jenkins UI."
    echo
    echo "Jenkins UI is accessible via the URL provided"
    echo "in your lab environment."
    echo "  Username: admin"
    echo "  Password: admin"
    echo
    echo "Job name: ${JOB_NAME}"
    echo
    echo "=========================================="
}

function main() {
    wait_for_jenkins
    install_plugins
    create_broken_jenkinsfile
    create_jenkins_job
    finalize
}

main