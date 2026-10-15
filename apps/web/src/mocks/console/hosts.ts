export type HostStatus = "online" | "offline" | "provisioning";

export interface MacHost {
  name: string;
  /** Where the Mac comes from, e.g. "AWS · mac2-m2.metal" or "Own Mac · Mac mini". */
  source: string;
  region: string;
  /** The AWS region code, or "office" for a Mac the team runs. */
  regionCode: string;
  chip: string;
  status: HostStatus;
  simulatorsRunning: number;
  simulatorSlots: number;
  /** "macOS 15.0 · Xcode 16.0", or what the host is doing instead. */
  software: string;
  /** When the 24-hour EC2 minimum ends; only AWS hosts have one. */
  billedUntil?: string;
}

export interface AwsRegion {
  city: string;
  code: string;
  /** Measured from the browser. */
  latencyMs: number;
}

export interface InstanceType {
  chip: string;
  /** The EC2 instance type, e.g. "mac2-m2.metal". */
  type: string;
  specs: string;
}

export interface AwsAccount {
  id: string;
  roleArn: string;
  role: string;
  externalId: string;
}

export interface AgentToken {
  value: string;
  expiresIn: string;
}

export const macHosts: MacHost[] = [
  {
    name: "sg-m2-01",
    source: "AWS · mac2-m2.metal",
    region: "Singapore",
    regionCode: "ap-southeast-1",
    chip: "Apple M2",
    status: "online",
    simulatorsRunning: 3,
    simulatorSlots: 4,
    software: "macOS 15.0 · Xcode 16.0",
    billedUntil: "Oct 15, 09:12",
  },
  {
    name: "sg-m2-02",
    source: "AWS · mac2-m2.metal",
    region: "Singapore",
    regionCode: "ap-southeast-1",
    chip: "Apple M2",
    status: "online",
    simulatorsRunning: 2,
    simulatorSlots: 4,
    software: "macOS 15.0 · Xcode 16.0",
    billedUntil: "Oct 15, 09:12",
  },
  {
    name: "tokyo-m1-01",
    source: "AWS · mac2.metal",
    region: "Tokyo",
    regionCode: "ap-northeast-1",
    chip: "Apple M1",
    status: "provisioning",
    simulatorsRunning: 0,
    simulatorSlots: 4,
    software: "Allocating · started 21:02",
    billedUntil: "Oct 15, 21:02",
  },
  {
    name: "studio-hcm-01",
    source: "Own Mac · Mac Studio",
    region: "Ho Chi Minh City",
    regionCode: "office",
    chip: "Apple M2",
    status: "online",
    simulatorsRunning: 4,
    simulatorSlots: 4,
    software: "macOS 14.6 · Xcode 16.0",
  },
  {
    name: "mini-hn-02",
    source: "Own Mac · Mac mini",
    region: "Hanoi",
    regionCode: "office",
    chip: "Apple M1",
    status: "offline",
    simulatorsRunning: 0,
    simulatorSlots: 2,
    software: "Last seen 2 h ago",
  },
];

export const awsRegions: AwsRegion[] = [
  { city: "Singapore", code: "ap-southeast-1", latencyMs: 38 },
  { city: "Tokyo", code: "ap-northeast-1", latencyMs: 71 },
  { city: "Seoul", code: "ap-northeast-2", latencyMs: 64 },
  { city: "Mumbai", code: "ap-south-1", latencyMs: 96 },
];

export const instanceTypes: InstanceType[] = [
  { chip: "Apple M1", type: "mac2.metal", specs: "8 vCPU · 16 GiB" },
  { chip: "Apple M2", type: "mac2-m2.metal", specs: "8 vCPU · 24 GiB" },
  { chip: "Apple M2 Pro", type: "mac2-m2pro.metal", specs: "12 vCPU · 32 GiB" },
];

export const awsAccount: AwsAccount = {
  id: "4821-3390-1176",
  roleArn: "arn:aws:iam::482133901176:role/IrisHostManager",
  role: "IrisHostManager",
  externalId: "iris-acme-7Hq2",
};

export const agentToken: AgentToken = { value: "irh_7Hq2Vx9KpL3mN8sR4tW6yZ1aQe", expiresIn: "59:12" };
