# Python Scripting Lab: Deployment Analytics at PipelineX

## Background

PipelineX runs continuous deployments across three environments: `prod`, `staging`, and `dev`. Every deployment is recorded in a CSV file with a start time, an end time, the target environment, and whether the deployment succeeded or failed.

A senior engineer has written most of `deploy_report.py`. The script reads the CSV, enriches each row by computing how long the deployment took, groups the rows by environment, and writes a summary report. Two core functions have been left unimplemented. The pipeline will produce incorrect output until you complete them.

---

## Your Task

Open `/home/user/deploy_report.py` and implement the two functions marked with `TODO`.

### Function 1: `compute_duration(start, end)`

This function receives two time strings in `HH:MM:SS` format, for example:

```
start = "08:00:00"
end   = "08:04:30"
```

It must return the duration in seconds as an integer. For the example above the correct return value is `270`.

You can assume `end` is always later than `start` and both are on the same day. Do not import any new modules -- the math can be done with string splitting and basic arithmetic.

### Function 2: `group_by_env(enriched_rows)`

This function receives a list of enriched deployment dictionaries. Each dict has these keys:

- `env` -- environment name, e.g. `"prod"`
- `status` -- either `"success"` or `"failed"`
- `duration_seconds` -- integer, already computed by `compute_duration`

It must return a dictionary keyed by environment name. Each value must be a dictionary with exactly these four keys:

- `total` -- total number of deployments in that environment
- `success` -- count of deployments with status `"success"`
- `failed` -- count of deployments with status `"failed"`
- `avg_duration_seconds` -- average duration across all deployments in that environment, rounded to the nearest integer

Do not import any new modules. Use the built-in `round()` function for the average.

---

## Success Criteria

- Running `python3 /home/user/deploy_report.py` completes without errors
- The output file `/home/user/deployreports/summary.txt` is created
- The report contains one line per environment: `prod`, `staging`, and `dev`
- The totals at the bottom show `total_deployments=10`, `total_failed=3`
- `prod` shows `avg_duration_seconds=288`, `staging` shows `163`, `dev` shows `102`

---

## Hints

- To convert `"08:04:30"` into seconds: split on `":"`, multiply hours by `3600`, minutes by `60`, add seconds.
- To compute the average, sum all durations and divide by the count. Use `round()` to get an integer result.
- You do not need to handle edge cases like missing keys or malformed rows -- the CSV is always well-formed.