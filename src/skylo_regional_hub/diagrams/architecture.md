flowchart TB
  subgraph OnPrem[Satellite Ground Stations / Regional POPs]
    GS1[Ground Station A]
    GS2[Ground Station B]
  end

  GS1 --> DX[Direct Connect]
  GS2 --> DX

  DX --> DXGW[Direct Connect Gateway]
  DXGW --> TGW[Transit Gateway]

  subgraph VPC[Regional Hub VPC (us-west-2)]
    subgraph Public[Public Subnets (3 AZs)]
      IGW[Internet Gateway]
      NAT1[NAT GW AZ-a]
      NAT2[NAT GW AZ-b]
      NAT3[NAT GW AZ-c]
      NLB[NLB/ALB Ingress]
    end

    subgraph PrivateApp[Private App Subnets (3 AZs)]
      EKS[EKS Cluster + NodeGroups]
      HPA[HPA / Karpenter]
    end

    subgraph PrivateData[Private Data Subnets (3 AZs)]
      Redis[ElastiCache Redis (Multi-AZ)]
      DDB[DynamoDB (regional)]
    end

    subgraph Logs[Log/Archive]
      S3[S3 Logs Bucket + Lifecycle]
    end

    TGWAttach[TGW Attachment Subnets (3 AZs)]
  end

  TGW --> TGWAttach
  TGWAttach --> EKS

  EKS --> Redis
  EKS --> DDB
  EKS --> S3
  EKS --> NAT1
  EKS --> NAT2
  EKS --> NAT3
