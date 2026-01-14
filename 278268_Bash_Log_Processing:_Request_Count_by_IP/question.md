## Bash Log Processing: Request Count by IP

You are given a log file named `server.log` that contains HTTP access records.
Each record is space-separated and follows a consistent structure.

In this file:

* The log contains a mix of request types (GET, POST, PUT, DELETE, etc.)
* The same IP address may appear multiple times across the file
* Each IP may make multiple requests of various types

---

### Task

Create a Bash script named **`count_requests.sh`** that:

1. Reads the file `server.log`
2. Identifies all **GET** requests
3. Extracts the **IP addresses** associated with those GET requests
4. Counts how many times each IP made a GET request
5. Sorts the results by count in **descending order** (highest count first)
6. Writes the output to a file named **`request_count.txt`**

---

### Output Requirements

* The output file `request_count.txt` must contain:

  * One line per unique IP address
  * Format: `<count> <IP_address>` (count followed by space, then IP)
  * Sorted by count in **descending order**
  * Only IPs that made **GET** requests

**Example output format:**
```
15 192.168.1.100
8 10.0.0.45
3 172.16.0.22
```

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
* Pay attention to the sorting requirement - numeric sort in descending order

---

### Deliverables

* `count_requests.sh`
* `request_count.txt`