# Python Scripting Lab: Log Pipeline at NovaDeploy Inc.

## Background

NovaDeploy Inc. runs a microservices platform and generates logs from three services: `app`, `db`, and `worker`. Every night, an on-call engineer manually scans these logs to count errors and warnings. You have been asked to automate this using a Python pipeline script.

A senior engineer has already written most of `log_pipeline.py`. The script reads log files, processes each line, and writes a daily summary report. However, two core functions have been left as stubs and the pipeline will not produce correct results until you implement them.

---

## Your Task

Open `/home/user/log_pipeline.py` and implement the two functions marked with `TODO`.

### Function 1: `parse_log_line(line)`

This function receives a single log line as a string, for example:

```
2024-03-01 08:15:44 ERROR Failed to process request: timeout after 30s
```

It must return a dictionary with exactly these four keys:

- `date` -- the date string, e.g. `"2024-03-01"`
- `time` -- the time string, e.g. `"08:15:44"`
- `level` -- the log level, e.g. `"ERROR"`
- `message` -- everything after the log level, e.g. `"Failed to process request: timeout after 30s"`

If the line has fewer than 4 parts, return `None`.

### Function 2: `summarize(parsed_lines, service_name)`

This function receives a list of parsed dictionaries (the output of `parse_log_line`) and the name of the service as a string. It must return a dictionary with these three keys:

- `service` -- the service name passed in
- `errors` -- count of lines where `level` is `"ERROR"`
- `warnings` -- count of lines where `level` is `"WARN"`

---

## Success Criteria

- Running `python3 /home/user/log_pipeline.py` completes without errors
- The output file `/home/user/logreports/summary.txt` is created
- The summary correctly reports `errors=<val>` and `warnings=<val>` across all three services
- The `app` service shows `errors=<val>`, `db` shows `errors=<val>`, `worker` shows `errors=<val>`
- `None` is returned by `parse_log_line` for malformed lines and the pipeline does not crash

---

## Hint

The log line format is space-separated. `str.split()` with a limit argument (`maxsplit`) will help you capture the message portion correctly, since the message itself can contain spaces.