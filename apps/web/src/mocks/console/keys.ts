/** A row of the API keys table. */
export interface ApiKey {
  name: string;
  /** Enough of the key to recognize it, e.g. "iris_sk_…7Hq2"; the full key is shown only once. */
  prefix: string;
  /** e.g. "Open sessions · Read devices". */
  permissions: string;
  createdBy: string;
  /** Already formatted, e.g. "2 h ago" or "Never". */
  lastUsed: string;
  /** Already formatted, e.g. "Jan 12, 2027", "In 6 days" or "Revoked Oct 2". */
  expires: string;
  /** `expiring` (within a week) shows the date in amber; `revoked` strikes the row through. */
  status: "active" | "expiring" | "revoked";
}

/** The key just created, which the dialog shows in full once. */
export interface NewApiKey {
  name: string;
  secret: string;
  permissions: string;
  projects: string;
  /** Already formatted, e.g. "Jan 12, 2027 · in 90 days". */
  expires: string;
}

export const apiKeys: ApiKey[] = [
  {
    name: "kedai-scripts", prefix: "iris_sk_…7Hq2", permissions: "Open sessions · Read devices", createdBy: "Minh Tran",
    lastUsed: "Never", expires: "Jan 12, 2027", status: "active",
  },
  {
    name: "qa-laptop-hcm", prefix: "iris_sk_…Lm4P", permissions: "Open sessions", createdBy: "Linh Pham",
    lastUsed: "2 h ago", expires: "Dec 1, 2026", status: "active",
  },
  {
    name: "host-automation", prefix: "iris_sk_…x9Te", permissions: "Manage Mac hosts", createdBy: "Minh Tran",
    lastUsed: "Yesterday", expires: "In 6 days", status: "expiring",
  },
  {
    name: "old-demo-key", prefix: "iris_sk_…Qa71", permissions: "Open sessions", createdBy: "Rizky Pratama",
    lastUsed: "Sep 28", expires: "Revoked Oct 2", status: "revoked",
  },
];

export const newKey: NewApiKey = {
  name: "kedai-scripts",
  secret: "iris_sk_live_5Fq9KpL3mN8sR4tW6yZ1aQeV7Hq2",
  permissions: "Open sessions · Read devices",
  projects: "kedai-android, kedai-ios",
  expires: "Jan 12, 2027 · in 90 days",
};
