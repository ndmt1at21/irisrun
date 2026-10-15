/** The current billing cycle and how much of the plan it has used. */
export interface BillingCycle {
  plan: string;
  /** Already formatted, e.g. "Oct 1 – Oct 31". */
  period: string;
  daysLeft: number;
  /** ISO date of the first day, marked "Cycle start" on the chart. */
  start: string;
  /** Session hours used and included in the plan. */
  virtual: { used: number; included: number };
  real: { used: number; included: number };
  /** Already formatted; the design keeps a placeholder until pricing is set. */
  estimate: string;
}

/** Session hours on one day of the chart. */
export interface UsageDay {
  /** ISO date, e.g. 2026-10-13. */
  date: string;
  virtual: number;
  real: number;
}

/** A row of "This cycle by project". */
export interface ProjectUsage {
  project: string;
  virtualHours: number;
  realHours: number;
  sessions: number;
}

export const cycle: BillingCycle = {
  plan: "Team",
  period: "Oct 1 – Oct 31",
  daysLeft: 17,
  start: "2026-10-01",
  virtual: { used: 88.3, included: 200 },
  real: { used: 24.8, included: 50 },
  estimate: "[AMOUNT]",
};

// [virtual, real] for Sep 15 – Oct 14, the 30 days the artboard draws.
const DRAWN: [number, number][] = [
  [5.2, 1.2], [6.1, 1.8], [5.8, 1.1], [4.9, 0.9], [0.8, 0], [0.4, 0], [6.3, 1.5], [7.1, 2.2], [6.8, 1.9], [7.4, 2.4],
  [5.9, 1.3], [1.1, 0.2], [0.6, 0], [7.8, 2.1], [8.2, 2.6], [7.6, 2.0], [8.9, 2.8], [6.4, 1.6], [1.4, 0.3], [0.7, 0],
  [8.8, 2.4], [9.1, 2.9], [8.4, 2.2], [9.6, 3.1], [7.2, 1.8], [1.2, 0.2], [0.9, 0.1], [9.4, 2.7], [10.2, 3.3], [6.1, 1.4],
];

const isoDay = (i: number) => new Date(Date.UTC(2026, 6, 17 + i)).toISOString().slice(0, 10);
const round = (hours: number) => Math.round(hours * 10) / 10;

/** Jul 17 – Oct 14, oldest first. The 60 days before the drawn ones keep the same weekday rhythm, a little lower. */
export const usageDays: UsageDay[] = [
  ...Array.from({ length: 60 }, (_, i): UsageDay => {
    const date = isoDay(i);
    const wobble = (Math.sin(i * 1.7) + 1) / 2;
    return new Date(date).getUTCDay() % 6 === 0
      ? { date, virtual: round(0.3 + wobble * 0.8), real: round(wobble * 0.3) }
      : { date, virtual: round(3.4 + i * 0.03 + wobble * 1.8), real: round(0.5 + wobble * 1.1) };
  }),
  ...DRAWN.map(([virtual, real], i) => ({ date: isoDay(60 + i), virtual, real })),
];

export const projectUsage: ProjectUsage[] = [
  { project: "kedai-ios", virtualHours: 52.6, realHours: 4.1, sessions: 71 },
  { project: "kedai-android", virtualHours: 30.2, realHours: 16.9, sessions: 94 },
  { project: "kedai-seller-android", virtualHours: 5.5, realHours: 3.8, sessions: 17 },
];
