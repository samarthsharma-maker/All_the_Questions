# LogHarvest Inc: Broken Log Processing Scripts

## Company Background

LogHarvest Inc provides a managed log aggregation service for enterprise clients. On each managed server, two bash scripts run as part of the daily log processing pipeline:

- `log-harvest`: scans application log directories, counts error events, and writes a summary to a daily report file
- `log-report`: reads the daily report CSV, computes per-service totals, and prints a formatted summary to stdout

Both scripts were refactored last sprint to support multiple log directories and a new CSV report format. The refactor passed code review but was never tested end-to-end before being deployed.

---

## Reported Issues

**Issue 1: Error count in the daily summary is always zero**

`log-harvest` runs without error and writes the report file, but the error count field in every report shows `0` regardless of how many error lines exist in the log files. Manually running `grep -c ERROR` on the same files returns the correct count.

**Issue 2: Errors from log-harvest are not captured in the log file**

When `log-harvest` encounters a problem (missing directory, permission denied), the error messages appear on the terminal instead of being written to the log file. The script redirects output to a log file but errors are escaping to stdout.

**Issue 3: log-report skips directories that contain spaces in their path**

`log-report` accepts a list of report directories as a bash array. When any directory path contains a space, it is split into two separate tokens and neither path resolves correctly. Paths without spaces work fine.

**Issue 4: log-report output totals are always zero, and the last CSV row is missing**

`log-report` runs without error but always prints `errors=0 warns=0 services=0` regardless of the CSV content. Additionally, the last entry in the report is never included in the output. The CSV file is valid and all rows are present on disk.

---

## Lab Environment

Both scripts are deployed in your home directory:

```
/home/user/log-harvest
/home/user/log-report
```

Sample data is available at:

```
/home/user/logharvest/logs/        -- application log files (app, db, worker)
/home/user/logharvest/reports/     -- daily CSV reports
/home/user/logharvest/script-logs/ -- harvest script output log
```

Your task is to find and fix all four bugs. Test your fixes by running the scripts directly:

```bash
bash /home/user/log-harvest
bash /home/user/log-report /home/user/logharvest/reports/daily.csv
```