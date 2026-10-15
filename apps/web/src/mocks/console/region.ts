/** A region the organization can keep its recordings, logs and screenshots in. */
export interface DataRegion {
  name: string;
  /** The AWS region code, e.g. ap-southeast-1. */
  code: string;
}

/** Where the data is now and how much of it there is. */
export interface StoredData extends DataRegion {
  /** Already formatted, e.g. "Aug 2, 2026". */
  since: string;
  recordings: number;
  size: string;
}

export const stored: StoredData = {
  name: "Singapore",
  code: "ap-southeast-1",
  since: "Aug 2, 2026",
  recordings: 128,
  size: "41 GB",
};

export const regions: DataRegion[] = [
  { name: "Singapore", code: "ap-southeast-1" },
  { name: "Tokyo", code: "ap-northeast-1" },
  { name: "Seoul", code: "ap-northeast-2" },
  { name: "Mumbai", code: "ap-south-1" },
  { name: "Jakarta", code: "ap-southeast-3" },
  { name: "Sydney", code: "ap-southeast-2" },
];

/** The organization's slug, typed to confirm a move. */
export const orgSlug = "acme-mobile";

/** How long recordings are kept: 7, 30 or 90 days. */
export const retentionDays = 30;
