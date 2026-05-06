# SQS + SNS + DLQ: Failed Delivery Alert Pipeline at VitalRoute Logistics

## Context

VitalRoute Logistics processes over 40,000 deliveries daily across 12 cities. When a delivery fails due to customer unavailability, wrong address, or vehicle breakdown, the ops team needs to be notified immediately so they can reassign the job before the SLA window closes.

The engineering team has designed an event-driven alerting pipeline:

- The delivery service publishes failed delivery events to an **SNS topic**
- SNS fans the message out to an **SQS queue** where a downstream processing service picks it up
- If a message fails to be processed 3 times, it is automatically moved to a **Dead Letter Queue** so the ops team can investigate and replay it manually

None of this infrastructure exists yet. You are responsible for building the entire pipeline, wiring the components together, and verifying that messages flow correctly from SNS through to SQS and eventually to the DLQ when processing fails.

Policy documents and a sample event payload have been prepared for you in `/home/user/vitalroute-alerts-lab/`. Run the setup script first if you have not already.

##### To save and exit vim: press `Ctrl + C`

---

## Environment Details

- **Region:** `us-west-2`
- **DLQ name:** `vitalroute-failed-delivery-dlq`
- **Main queue name:** `vitalroute-failed-delivery-queue`
- **SNS topic name:** `vitalroute-delivery-alerts`
- **Max receive count:** `3`

---

## Tasks

### Task 1: Create the Dead Letter Queue

Create a standard SQS queue named `vitalroute-failed-delivery-dlq`. This queue will hold messages that could not be processed after 3 attempts. Create this before the main queue.

### Task 2: Create the Main Queue with DLQ Wired In

Create a standard SQS queue named `vitalroute-failed-delivery-queue`. Under the Dead Letter Queue section, set the DLQ to `vitalroute-failed-delivery-dlq` and set Maximum Receives to `3`.

### Task 3: Create the SNS Topic

Create a standard SNS topic named `vitalroute-delivery-alerts`.

### Task 4: Subscribe the SQS Queue to the SNS Topic

Create a subscription on the SNS topic. Set the protocol to Amazon SQS and select `vitalroute-failed-delivery-queue` as the endpoint.

### Task 5: Apply the Queue Policy

Open the main queue in the SQS console. Under the Access Policy tab, replace the existing policy with the contents of `queue-policy.json` from your lab directory. This grants SNS permission to deliver messages to the queue.

### Task 6: Publish a Test Event and Verify

Publish the contents of `failed-delivery-event.json` from your lab directory to the SNS topic. Then poll the main queue and confirm the delivery event payload is present in the message body.

```bash
aws sns publish \
  --topic-arn <YOUR-TOPIC-ARN> \
  --message file:///home/user/vitalroute-alerts-lab/failed-delivery-event.json \
  --region us-west-2

aws sqs receive-message \
  --queue-url <YOUR-QUEUE-URL> \
  --region us-west-2
```

### Task 7: Simulate DLQ Routing

First reduce the visibility timeout on the main queue to speed up the simulation. Then receive the message 3 times without deleting it, waiting for the visibility timeout to expire between each attempt. After the third receive SQS will automatically move the message to the DLQ.

```bash
aws sqs set-queue-attributes \
  --queue-url <YOUR-QUEUE-URL> \
  --attributes VisibilityTimeout=5 \
  --region us-west-2

# Run this 3 times, waiting 6 seconds between each run
aws sqs receive-message \
  --queue-url <YOUR-QUEUE-URL> \
  --region us-west-2

# Verify message landed in DLQ
aws sqs receive-message \
  --queue-url <YOUR-DLQ-URL> \
  --region us-west-2
```

---

## Notes

- Create the DLQ before the main queue. The redrive policy references the DLQ ARN and will fail if the DLQ does not exist yet.
- SQS subscriptions to SNS auto-confirm. If the subscription shows PendingConfirmation the queue policy is likely missing or incorrect.
- Between each receive attempt in Task 7, wait for the visibility timeout to expire before receiving again. SQS does not count a re-receive within the same visibility window as a new attempt. Set the visibility timeout to a low value like 5 seconds to speed this up.
- Use `us-west-2` for all resources.