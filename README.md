1. Overview

This document proposes an AWS-based Regional Hub architecture to support Skylo’s Non-Terrestrial Network (NTN) services. The hub ingests high-volume, low-latency traffic from satellite ground stations via Direct Connect and runs containerized 3GPP core network functions (NFs) responsible for session management, control plane signaling, and user plane data routing.

The design prioritizes:

    High availability across AZ failure domains

    Elastic scaling for traffic bursts and session churn

    Security-by-design aligned with SOC 2 principles

    Automation-first via Infrastructure as Code (Terraform)

2) Network design (VPC, subnets, routes, NAT, TGW)

VPC + subnets

Goal: multi-AZ, blast-radius isolation, clear separation of tiers.

    VPC CIDR: 10.80.0.0/16 (example)

    AZs: us-west-2a, us-west-2b, us-west-2c

Subnet layout (per AZ):
 
    Public subnet (ingress + NAT): /20

    Private app subnet (EKS nodes/pods): /19

    Private data subnet (Redis, future RDS, etc.): /21

    TGW attachment subnet: /24

Example mapping:

Tier	              AZ-a	                  AZ-b	                    AZ-c
Public	          10.80.0.0/20	           10.80.16.0/20	        10.80.32.0/20
Private App	      10.80.64.0/19	           10.80.96.0/19	        10.80.128.0/19
Private Data	  10.80.160.0/21	       10.80.168.0/21	        10.80.176.0/21
TGW Attach	      10.80.240.0/24	       10.80.241.0/24	        10.80.242.0/24

Why this is good:

    Keeps room for future growth (new app subnets, endpoints, more tiers)

    TGW subnets are small/dedicated (clean routing, less accidental exposure)

    App tier has the most IPs (pods + nodes scaling)

Route tables

    Public route table: 0.0.0.0/0 -> IGW

    Private app route table (per AZ): 0.0.0.0/0 -> NAT GW (same AZ) (avoid cross-AZ NAT costs + resilience)

    Private data route table: typically no default route to IGW unless required; allow only what’s needed via NAT or VPC endpoints.

    TGW route table: routes to organization CIDRs via TGW; only allow required prefixes.

VPC endpoints (security + cost)

Enable early:

    Gateway endpoints: S3, DynamoDB

    Interface endpoints: ECR (api + dkr), CloudWatch Logs, STS, SSM, KMS, Secrets Manager
    This reduces NAT egress, improves security posture, and supports “zero-trust” private access to AWS services.

3) Compute platform choice (EKS vs ECS)

Recommendation: EKS (primary) for the 3GPP core workloads.

Why EKS fits better here:

    Operational model: 3GPP core components often have multi-service, service discovery, complex networking, and tight SLO needs. Kubernetes gives richer primitives (HPA, PDBs, affinity/anti-affinity, disruption controls).

    Scaling: Native HPA + Cluster Autoscaler / Karpenter for node scaling, plus pod-level autoscaling per component.

    Security: IRSA, network policies, service mesh (optional), admission control, pod security, fine-grained RBAC.

    Ecosystem: Prometheus/Grafana, OTel, policy engines, GitOps, etc.

Trade-off:

    EKS is more complex than ECS. If the workload were simpler stateless services, ECS/Fargate would reduce overhead.

    For core network components with nuanced scaling + networking + runtime policies, EKS tends to be worth it.

Compute design notes:

    EKS control plane is multi-AZ by AWS design.

    Worker nodes (managed node groups) spread across 3 AZs.

    Use taints/tolerations and node affinity for separating “core processing” from “support services” nodes.

    Consider Bottlerocket or hardened AMIs for node OS.

    Ingress can be NLB for L4 high-throughput and predictable latency (common for telecom-ish patterns), or ALB if you need L7 routing.

4) Data storage (session state vs long-term logs)

Short-term session state (high-throughput, low-latency)

Recommendation: ElastiCache Redis (cluster-mode + Multi-AZ) for hot session state / near-real-time state.

Why:

    Microsecond–millisecond latency

    Supports high write rates and fast key lookups for session/session-token/state

    Multi-AZ with automatic failover

    Can be sized independently from the compute tier

Alternative / complementary: DynamoDB

    If session state needs strong durability or want serverless scaling, DynamoDB is excellent.

    Pattern I like: Redis as hot cache/state + DynamoDB as source of truth (depending on what “session state” means in their 3GPP implementation).

    If it’s truly ephemeral session data, Redis alone is often sufficient.

Long-term archival of connection logs

Recommendation: S3 as the primary log lake:

S3 bucket with:

    encryption (SSE-KMS)

    bucket policy blocking public access

    lifecycle (Standard → IA → Glacier)

    partitioning by date/region/component

Optional add-ons:

    Athena for querying

    Glue catalog

    Lake Formation (if access governance becomes complex)

5) High availability + DR strategy

HA within us-west-2

    Multi-AZ subnets for all tiers

    NAT per AZ (no single point of egress)

    EKS node groups across AZs

    Redis Multi-AZ with automatic failover

    If using ALB/NLB, enable cross-zone load balancing where appropriate

    Use PDBs + topology spread constraints so a single AZ loss doesn’t evict everything

Regional DR (if us-west-2 fails)

High-level strategy: warm standby in another region (e.g., us-east-1).

    IaC can provision the same hub in DR region

    ECR replication (or CI builds images into both regions)

    S3 Cross-Region Replication for logs (or log shipping to a central bucket)

    DynamoDB Global Tables if DDB is used for durable session/state

Redis:

    either rebuild in DR and accept some loss of ephemeral state

    or use application-level session rehydration strategy

Connectivity:

    Direct Connect can fail over to Site-to-Site VPN as backup, or use dual DX locations if available

Cutover:

    Route 53 health checks + failover, or Global Accelerator (if internet-facing)

    For DX-only private endpoints, failover is often routing/BGP + enterprise network coordination

Note:

I would start with warm standby to balance cost and recovery time, and only move to active/active if RTO/RPO requirements justify the added operational and networking complexity.
