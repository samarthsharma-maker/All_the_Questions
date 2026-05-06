#!/bin/bash

set -euo pipefail

TARGET_DIR="/home/user"
STUDENTS_CSV="${TARGET_DIR}/students.csv"
EXAM_SCORES_JSON="${TARGET_DIR}/exam_scores.json"
SYSTEM_LOG="${TARGET_DIR}/system.log"

# Create students.csv file
function create_students_csv() {
    cat > "${STUDENTS_CSV}" <<'EOF'
student_id,name,email,department
101,Alice Smith,alice.smith@university.edu,CS
102,Bob Jones,bob.j@university.edu,Math
103,Charlie Brown,charlie.brown@university.edu,CS
104,Diana Prince,diana.invalid-email,Physics
105,Eve Wilson,eve.wilson@university.edu,Math
106,Frank Miller,frank.miller@university.edu,CS
107,Grace Lee,grace.lee@uni.edu,Physics
108,Henry Davis,henry@university,Math
109,Iris Chen,iris.chen@university.edu,CS
110,Jack Thompson,jack.thompson@university.edu,Physics
EOF
}

# Create exam_scores.json file
function create_exam_scores_json() {
    cat > "${EXAM_SCORES_JSON}" <<'EOF'
{
  "exam_date": "2024-02-01",
  "exam_name": "Midterm Examination",
  "total_marks": 100,
  "scores": [
    {"student_id": 101, "score": 85},
    {"student_id": 102, "score": 92},
    {"student_id": 103, "score": 78},
    {"student_id": 104, "score": 88},
    {"student_id": 105, "score": 95},
    {"student_id": 106, "score": 72},
    {"student_id": 107, "score": 88},
    {"student_id": 108, "score": 91},
    {"student_id": 109, "score": 85},
    {"student_id": 110, "score": 79}
  ]
}
EOF
}

# Create system.log file
function create_system_log() {
    cat > "${SYSTEM_LOG}" <<'EOF'
2024-02-01 08:45:12 INFO System initialized for exam session
2024-02-01 09:00:00 INFO Exam portal opened
2024-02-01 09:15:23 INFO Student 101 started exam
2024-02-01 09:16:45 INFO Student 102 started exam
2024-02-01 09:18:30 ERROR Student 103 authentication failed - invalid credentials
2024-02-01 09:20:15 INFO Student 103 started exam
2024-02-01 09:22:50 INFO Student 104 started exam
2024-02-01 09:25:33 ERROR Student 111 authentication failed - student not found
2024-02-01 09:28:10 INFO Student 105 started exam
2024-02-01 09:30:45 WARNING Student 106 connection unstable
2024-02-01 09:32:20 INFO Student 106 started exam
2024-02-01 09:35:55 INFO Student 107 started exam
2024-02-01 09:38:40 ERROR Student 108 authentication failed - network timeout
2024-02-01 09:40:12 INFO Student 108 started exam
2024-02-01 09:42:30 INFO Student 109 started exam
2024-02-01 09:45:18 INFO Student 110 started exam
2024-02-01 10:15:23 INFO Student 101 completed exam
2024-02-01 10:18:45 INFO Student 102 completed exam
2024-02-01 10:20:15 INFO Student 103 completed exam
2024-02-01 10:25:50 INFO Student 104 completed exam
2024-02-01 10:28:10 INFO Student 105 completed exam
2024-02-01 10:32:20 WARNING Student 106 submitted with 2 minutes remaining
2024-02-01 10:32:45 INFO Student 106 completed exam
2024-02-01 10:35:55 INFO Student 107 completed exam
2024-02-01 10:40:12 INFO Student 108 completed exam
2024-02-01 10:42:30 ERROR Student 109 submission failed - timeout
2024-02-01 10:43:15 INFO Student 109 completed exam
2024-02-01 10:45:18 INFO Student 110 completed exam
2024-02-01 11:00:00 INFO Exam portal closed
2024-02-01 11:05:30 ERROR Student 112 attempted late access - denied
2024-02-01 11:10:45 INFO All submissions processed successfully
EOF
}

# Create all files
echo "Creating ${STUDENTS_CSV}..."
create_students_csv
chown user:user "${STUDENTS_CSV}" 2>/dev/null || true

echo "Creating ${EXAM_SCORES_JSON}..."
create_exam_scores_json
chown user:user "${EXAM_SCORES_JSON}" 2>/dev/null || true

echo "Creating ${SYSTEM_LOG}..."
create_system_log
chown user:user "${SYSTEM_LOG}" 2>/dev/null || true

echo "Setup complete! All prerequisite files created in ${TARGET_DIR}"