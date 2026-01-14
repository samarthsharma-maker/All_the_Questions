## Bash Log Processing: Successful Request IPs

You are given a log file named `web.log` that contains HTTP access records.
Each record is **space-separated** and follows a consistent structure.

In this file:

* The log contains a mix of request types (GET, POST, OPTIONS, etc.)
* The log contains various HTTP status codes (200, 401, 403, etc.)
* Successful requests are indicated by status code **200**
* The same IP address may appear multiple times

---

### Task

Create a Bash script named **`successful_ips.sh`** that:

1. Reads the file `web.log`
2. Identifies all **successful requests** (status code 200)
3. Extracts the **IP addresses** associated with those successful requests
4. Removes duplicate IPs
5. Sorts the result alphabetically
6. Writes the output to a file named **`unique_success_ips.txt`**

---

### Output Requirements

* The output file `unique_success_ips.txt` must contain:

  * One IP address per line
  * Only **unique** IP addresses
  * Only IPs from requests with **status code 200**
  * Sorted **alphabetically**

**Example output format:**
```
123.45.67.89
185.220.101.33
192.168.1.100
203.0.113.200
45.33.21.156
98.76.54.32
```

---

### Constraints

* The script must be written in **Bash**
* You **must** use:
  * `grep` for filtering
  * `awk` for field extraction
* Do **not** use:
  * Python, Perl, or any other programming language
  * External log-processing tools

---

### Notes

* The log file may contain **thousands of entries**
* An IP can make multiple successful requests
* Only status code 200 indicates success (not 401, 403, etc.)
* The script should work for any file that follows the same structure
* The solution will be evaluated for **correctness**, **robustness**, and **command-line proficiency**


---

### Deliverables

* `successful_ips.sh`
* `unique_success_ips.txt`