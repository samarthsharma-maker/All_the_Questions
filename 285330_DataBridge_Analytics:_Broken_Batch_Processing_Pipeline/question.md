# DataBridge Analytics: Broken Batch Processing Pipeline

## Company Background

DataBridge Analytics runs a batch data processing pipeline on a dedicated Ubuntu server. The pipeline is composed of four components, all managed by a single SRE team:

- A systemd service (`databridge`) that runs the processing daemon continuously
- A processing script (`/usr/local/bin/databridge-process`) that the daemon invokes to handle data files
- A nightly cron job that purges processed data from the working directory
- A health-check script (`/usr/local/bin/databridge-healthcheck`) that monitors the daemon and triggers recovery when it becomes unhealthy

All four components were authored by the same engineer and deployed together last week. Since deployment, the ops team has opened four separate incidents.

---

## Reported Incidents

**Incident 1: Service starts but runs with an empty environment**

The `databridge` service reports `active (running)` in `systemctl status`, but the daemon behaves as though no configuration was loaded. Environment variables that should be sourced from the config file (`BATCH_SIZE`, `BATCH_FLAGS`, `DB_HOST`) are all empty at runtime. The config file exists on disk at the expected location.

**Incident 2: Batch threshold check fires on every run**

The processing script contains a threshold check that should emit a warning only when the batch count exceeds a configured limit. The warning fires on every single run regardless of the actual file count. A file with an unexpected name is also appearing in `/usr/local/bin/` after each execution.

**Incident 3: Nightly cleanup cron job produces no output and no effect**

The cron entry exists in `/etc/cron.d/databridge-cleanup` with the correct schedule, but processed files are never removed. No error emails are delivered and no log entries are written. The cleanup script executes successfully when invoked manually under the `user` account.

**Incident 4: Service enters a degraded state after health-check recovery**

When the health-check script detects an unhealthy daemon, the service transitions to a degraded state rather than recovering. Post-incident review indicates the recovery mechanism does not go through systemd, leaving the unit in a state that requires manual intervention (`systemctl reset-failed`) before it can be restarted.

---

## Lab Environment

All four broken components are deployed on this system. Your task is to locate and fix each bug.

Relevant files:

```
/etc/systemd/system/databridge.service
/etc/databridge/databridge.conf
/usr/local/bin/databridge-process
/etc/cron.d/databridge-cleanup
/usr/local/bin/databridge-cleanup
/usr/local/bin/databridge-healthcheck
```

After modifying the systemd unit file, apply changes with:

```bash
sudo systemctl daemon-reload
sudo systemctl restart databridge
```

#### Use Sudo Wherever Necessary
#### Password : `user@123!`