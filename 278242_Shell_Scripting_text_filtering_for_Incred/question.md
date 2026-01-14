## Bash Log Processing: Unique Ips

You are given a log file named `log.tf` that contains HTTP access records.
Each record is space-separated and follows a consistent structure.

In this file:

* The log contains a mix of request types (GET, POST, OPTIONS, etc.)
* The same IP address may appear multiple times across the file

---

### Task

Create a Bash script named **`unique_ips.sh`** that:

1. Reads the file `log.tf`
2. Identifies all **POST** requests
3. Extracts the **IP addresses** associated with those POST requests
4. Removes duplicate IPs
5. Sorts the final result
6. Writes the output to a file named **`unique_ip.txt`**

---

### Output Requirements

* The output file `unique_ip.txt` must contain:

  * One IP address per line
  * Only **unique** IP addresses
  * Only IPs that made **POST** requests

---

### Constraints

* The script must be written in **Bash**
* Do **not** use:
  * Python, Perl, or any other programming language
  * External log-processing tools

---

### Notes

* The log file may contain **thousands of entries**
* The script should work for any file that follows the same structure
* The solution will be evaluated for **correctness**, **robustness**, and **command-line proficiency**

---

### Deliverables

* `unique_ips.sh`
* `unique_ip.txt`


