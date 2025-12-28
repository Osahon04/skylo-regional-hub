Task 3 — Security & Observability 

1. SECURITY

IAM roles for workloads (EKS: IRSA)

Create:

IRSA roles per service (not one shared role):

    core-session-manager-sa-role

    core-routing-sa-role

    core-ingress-parser-sa-role

Each role has only the needed actions and scoped resources.

What I explicitly avoid granting

    *:* wildcards

Any broad IAM admin actions:

    iam:*, sts:AssumeRole to arbitrary roles

Unscoped KMS access:

    avoid kms:* on *

Broad S3:

    avoiding s3:* on all buckets; scope to bucket/path-prefix

EC2 control:

    avoiding ec2:* unless a controller genuinely needs it (e.g., cluster autoscaler needs limited permissions)

Kubernetes controls (zero-trust posture)

    Pod security (restricted baseline)

    Network Policies (deny-by-default between namespaces)

    Separate namespaces per component domain

    Optional service mesh mTLS between services (if needed for internal zero-trust)

THE FIRST 3 AWS SECURITY SERVICE I WILL ENABlE

1. AWS KMS (with CMKs)

    Encrypting everything (EKS secrets envelope, S3, Redis auth/token material, logs)

    Tight key policies + rotation

2. GuardDuty

    Threat detection for compromised instances, credential exfiltration patterns, DNS anomalies, suspicious API calls

3. Security Hub (plus foundational standards)

    Aggregates findings (GuardDuty, IAM Access Analyzer, Inspector, etc.)

    Track posture against SOC2 controls; drive remediation workflow




2. OBSERVABILITY


TOP 3 METRICS FOR CONTAINERIZED WORKLOADS

Picking metrics that shows user impact + saturation + stability:

1. p95/p99 request or processing latency per core component

     tells me real user/session impact

2. Error rate / failure rate

    5xx, dropped packets, failed session establishments, etc.

3. Resource saturation (CPU/memory + throttling)

    CPU throttling, memory working set, pod OOMKills, HPA scaling events


Logging/monitoring/alerting stack

1. Metrics: Prometheus + Grafana or CloudWatch Container Insights (or both)

2. Tracing: OpenTelemetry Collector → (CloudWatch/X-Ray or Datadog APM)

3. Logs: Fluent Bit/Vector → CloudWatch Logs (centralized), optional OpenSearch for     search-heavy use cases

4. Alerting: CloudWatch alarms + PagerDuty/Slack, or Prometheus Alertmanager + Slack/PagerDuty