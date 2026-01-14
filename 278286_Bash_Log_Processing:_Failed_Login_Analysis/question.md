## Bash Log Processing: Failed Login Analysis

You are given a log file named `access.log` that contains HTTP access records.
Each record is **semicolon-separated** and follows a consistent structure.

In this file:

* The log contains a mix of request types (GET, POST, OPTIONS, etc.)
* The log contains various HTTP status codes (200, 401, 403, etc.)
* Failed authentication attempts are indicated by status codes **401** (Unauthorized) or **403** (Forbidden)
* The same IP address may appear multiple times with different status codes

---

### Task

Create a Bash script named **`failed_logins.sh`** that:

1. Reads the file `access.log`
2. Identifies all **failed authentication attempts** (status codes 401 or 403)
3. Extracts the **IP addresses** associated with those failed attempts
4. Groups and counts failed attempts per IP
5. Filters to show only IPs with **3 or more** failed attempts
6. Sorts by failure count in **descending order**
7. Writes the output to a file named **`suspicious_ips.txt`**

---

### Output Requirements

* The output file `suspicious_ips.txt` must contain:

  * One line per IP address
  * Format: `<count> <IP_address>` (failure count followed by space, then IP)
  * Only IPs with **3 or more** failed attempts
  * Sorted by count in **descending order** (most failures first)

**Example output format:**
```
5 45.33.21.156
3 98.76.54.32
3 185.220.101.33
```

---

### Constraints

* The script must be written in **Bash**
* You **must** use:
  * `grep` for filtering
  * `awk` for field extraction and processing
* Do **not** use:
  * Python, Perl, or any other programming language
  * External log-processing tools

---

### Notes

* The log file may contain **thousands of entries**
* An IP can have multiple failed attempts across different endpoints
* Status codes 401 and 403 both indicate authentication failures
* The script should work for any file that follows the same structure
* The solution will be evaluated for **correctness**, **robustness**, and **command-line proficiency**


---

### Deliverables

* `failed_logins.sh`
* `suspicious_ips.txt`