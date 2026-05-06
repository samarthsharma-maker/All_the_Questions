# S3 Versioning: Incident Recovery at VitalRoute Logistics

## Context

VitalRoute Logistics runs a daily delivery reporting pipeline that generates a `report.csv` file containing delivery outcomes across all cities. This file is stored in an S3 bucket with versioning enabled, serving as the source of truth for the operations team's end-of-day review.

This morning, a junior engineer accidentally deleted `report.csv` from the bucket while cleaning up old files. The operations team is blocked — they cannot complete their city-level delivery review without it. To make things worse, a recent audit flagged that the bucket's public access block is fully disabled, meaning the bucket could be exposed to the internet. And there is no lifecycle policy in place, so old file versions are accumulating indefinitely with no cleanup.

You have been pulled in to fix all three issues before the 9 AM ops review call.

Your job is to recover the file, secure the bucket, and set a retention policy.

### To save and exit vim: press `Ctrl + C`

---

## Environment Details

- **Region:** `us-west-2`
- **Bucket name:** printed in your terminal after running the setup script
- **File to recover:** `report.csv`

---

## Tasks

### Task 1: Recover the Deleted File

The file was not permanently deleted — because versioning is enabled, S3 created a delete marker instead. Open the S3 console, navigate to your bucket, and enable the **Show versions** toggle to see all versions including the delete marker.

Identify the delete marker for `report.csv` and delete it using its version ID. This will restore the file to its previous state.

Once done, verify the file is accessible:

```bash
aws s3 ls s3://<YOUR-BUCKET-NAME>/
```

### Task 2: Disable Public Access

The bucket currently has all public access block settings turned off. Enable full public access blocking on the bucket so no objects can be made public under any circumstances.

Once done, verify the configuration:

```bash
aws s3api get-public-access-block --bucket <YOUR-BUCKET-NAME>
```

All four fields should show `true`.

### Task 3: Add a Lifecycle Rule

Add a lifecycle rule named `expire-old-versions` to the bucket that automatically expires non-current versions of all objects after 30 days.

Once done, verify the rule is applied:

```bash
aws s3api get-bucket-lifecycle-configuration --bucket <YOUR-BUCKET-NAME>
```

---

## Notes

- The bucket name is printed in your terminal after the setup script runs. Copy it before starting.
- The delete marker has its own version ID separate from the actual file version. Make sure you are deleting the marker and not the file version itself.
- The lifecycle rule applies to non-current versions only — it should not affect the current live version of any object.
- Use `us-west-2` for all commands that require a region.