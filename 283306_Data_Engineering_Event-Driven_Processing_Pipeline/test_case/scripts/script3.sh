#!/bin/bash

source "/usr/local/bin/judge/test/common.sh"
unset -f handle_internal_error
unset -f handle_script_error
trap - ERR

REGION="${AWS_REGION:-us-west-2}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
PROCESSED_BUCKET="salary-processed-bucket-${ACCOUNT_ID}"
OUTPUT_KEY="output/deptMonthAggSalary${ACCOUNT_ID}.csv"

function test_march_aggregation() {
    local content
    content=$(aws s3 cp "s3://${PROCESSED_BUCKET}/${OUTPUT_KEY}" - --region "$REGION" 2>/dev/null)

    # Expected March totals per dept (includes duplicate emp_id=2 Riya rows — both counted):
    # 101: Amit(53000) + Sneha(61000) + Rahul(51000) + Aditya(65000) + Rohit(58000) = 288000
    # 102: Riya(62000) + Riya(6000)   + Priya(63000) + Laura(59000)  + Anita(52000) = 242000
    # 103: John(58000) + Karan(54000) + Vikram(67000) + David(60000)                = 239000
    # 104: Arjun(65000) + Isha(56000) + Pooja(49000)                                = 170000
    # 105: Meera(55000) + Neha(53000) + Sam(61000)                                  = 169000

    declare -A expected
    expected[101]="288000"
    expected[102]="242000"
    expected[103]="239000"
    expected[104]="170000"
    expected[105]="169000"

    local failed=0
    for dept in 101 102 103 104 105; do
        local actual
        actual=$(echo "$content" | grep "^${dept},Mar," | cut -d',' -f3 | tr -d '[:space:]')
        if [ "$actual" != "${expected[$dept]}" ]; then
            print_status "failed" "Test 7 Failed: dept_id=${dept}, month=Mar — Expected ${expected[$dept]}, got '${actual}'"
            failed=1
        fi
    done

    if [ "$failed" -eq 0 ]; then
        print_status "success" "Test 7 Passed: March aggregation totals are correct for all departments"
    else
        exit 1
    fi
}

test_march_aggregation
print_status "success" "March Aggregation Test Passed."
exit 0