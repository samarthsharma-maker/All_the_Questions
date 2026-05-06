#!/bin/bash

set -euo pipefail

TARGET_DIR="/home/user"
SOLUTION_FILE="${TARGET_DIR}/analyze_exam.py"

# Create the solution script
function create_solution() {
    cat > "${SOLUTION_FILE}" <<'EOF'
#!/usr/bin/env python3

# Function to read CSV file
def read_csv(filename):
    students = []
    with open(filename, 'r') as file:
        lines = file.readlines()
        # Skip header
        for i in range(1, len(lines)):
            line = lines[i].strip()
            if line:
                parts = line.split(',')
                student = {
                    'student_id': parts[0],
                    'name': parts[1],
                    'email': parts[2],
                    'department': parts[3]
                }
                students.append(student)
    return students

# Function to read JSON file
def read_json(filename):
    with open(filename, 'r') as file:
        content = file.read()
    
    # Parse JSON manually
    scores = []
    # Find the scores array
    start = content.find('"scores":')
    if start == -1:
        return scores
    
    # Find the opening bracket of scores array
    bracket_start = content.find('[', start)
    bracket_end = content.rfind(']')
    
    scores_content = content[bracket_start+1:bracket_end]
    
    # Split by objects
    objects = scores_content.split('},')
    
    for obj in objects:
        obj = obj.strip()
        if not obj:
            continue
        
        # Extract student_id
        id_start = obj.find('"student_id":')
        if id_start != -1:
            id_start = id_start + len('"student_id":')
            id_end = obj.find(',', id_start)
            if id_end == -1:
                id_end = obj.find('}', id_start)
            student_id = obj[id_start:id_end].strip()
        
        # Extract score
        score_start = obj.find('"score":')
        if score_start != -1:
            score_start = score_start + len('"score":')
            score_end = obj.find('}', score_start)
            if score_end == -1:
                score_end = len(obj)
            score = obj[score_start:score_end].strip()
            score = score.replace('}', '').strip()
        
        scores.append({
            'student_id': student_id,
            'score': int(score)
        })
    
    return scores

# Function to validate email using regex pattern
def validate_email(email):
    # Pattern: ^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$
    
    # Check if @ exists
    if '@' not in email:
        return False
    
    # Split by @
    parts = email.split('@')
    if len(parts) != 2:
        return False
    
    local = parts[0]
    domain = parts[1]
    
    # Check local part (before @)
    if len(local) == 0:
        return False
    
    valid_local_chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-'
    for char in local:
        if char not in valid_local_chars:
            return False
    
    # Check domain part (after @)
    if len(domain) == 0:
        return False
    
    # Must have at least one dot
    if '.' not in domain:
        return False
    
    # Check characters in domain
    valid_domain_chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-'
    for char in domain:
        if char not in valid_domain_chars:
            return False
    
    # Check TLD (after last dot) has at least 2 letters
    last_dot_index = domain.rfind('.')
    tld = domain[last_dot_index+1:]
    
    if len(tld) < 2:
        return False
    
    # TLD should only contain letters
    for char in tld:
        if char not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ':
            return False
    
    return True

# Function to read log file and extract errors
def read_log_errors(filename):
    errors = []
    with open(filename, 'r') as file:
        lines = file.readlines()
        for line in lines:
            if 'ERROR' in line:
                errors.append(line.strip())
    return errors

# Function to calculate statistics
def calculate_statistics(scores):
    if len(scores) == 0:
        return 0, 0, 0
    
    # Calculate average
    total = 0
    for score in scores:
        total += score['score']
    average = total / len(scores)
    
    # Find highest
    highest = scores[0]['score']
    for score in scores:
        if score['score'] > highest:
            highest = score['score']
    
    # Find lowest
    lowest = scores[0]['score']
    for score in scores:
        if score['score'] < lowest:
            lowest = score['score']
    
    return average, highest, lowest

# Main execution
def main():
    # Read all input files
    students = read_csv('/home/user/students.csv')
    scores = read_json('/home/user/exam_scores.json')
    errors = read_log_errors('/home/user/system.log')
    
    # Calculate statistics
    average, highest, lowest = calculate_statistics(scores)
    
    # Count students who passed (score >= 75)
    passed_count = 0
    for score in scores:
        if score['score'] >= 75:
            passed_count += 1
    
    # Find invalid emails
    invalid_emails = []
    for student in students:
        if not validate_email(student['email']):
            invalid_emails.append(student)
    
    # Generate exam_report.txt
    with open('/home/user/exam_report.txt', 'w') as file:
        file.write('STUDENT PERFORMANCE REPORT\n')
        file.write('====================================\n')
        file.write('\n')
        file.write('Total Students: ' + str(len(students)) + '\n')
        file.write('Average Score: ' + '{:.2f}'.format(average) + '\n')
        file.write('Highest Score: ' + str(highest) + '\n')
        file.write('Lowest Score: ' + str(lowest) + '\n')
        file.write('\n')
        file.write('Students Passed (Score >= 75): ' + str(passed_count) + '\n')
        file.write('\n')
        file.write('====================================\n')
    
    # Generate error_report.txt
    with open('/home/user/error_report.txt', 'w') as file:
        file.write('SYSTEM ERROR REPORT\n')
        file.write('====================================\n')
        file.write('\n')
        file.write('Total ERROR entries found: ' + str(len(errors)) + '\n')
        file.write('\n')
        file.write('ERROR DETAILS:\n')
        file.write('--------------\n')
        for error in errors:
            file.write(error + '\n')
        file.write('\n')
        file.write('====================================\n')
    
    # Generate invalid_emails.txt
    with open('/home/user/invalid_emails.txt', 'w') as file:
        file.write('INVALID EMAIL ADDRESSES\n')
        file.write('====================================\n')
        file.write('\n')
        for student in invalid_emails:
            file.write('Student ID ' + student['student_id'] + ': ' + student['name'] + '\n')
            file.write('Email: ' + student['email'] + '\n')
            file.write('\n')
        file.write('====================================\n')

# Run the main function
if __name__ == '__main__':
    main()
EOF
}

# Create the solution file
echo "Creating solution script ${SOLUTION_FILE}..."
create_solution

# Make it executable
chmod +x "${SOLUTION_FILE}" 2>/dev/null || true

# Set ownership
chown user:user "${SOLUTION_FILE}" 2>/dev/null || true

echo "Solution script created successfully at ${SOLUTION_FILE}"