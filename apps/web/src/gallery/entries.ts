import { scenarios } from "../mocks/scenarios";

export interface GalleryEntry {
  /** A router path with any `?mock=` state, e.g. `/console/hosts?mock=empty`. */
  href: string;
  title: string;
  /** The design file it reproduces, without `.dc.html`. */
  artboard: string;
}

export const deviceEntries: GalleryEntry[] = [
  ...scenarios.map(({ id, title, artboard }) => ({ href: `/?mock=${id}`, title, artboard })),
  { href: "/binaries", title: "Binary Doctor", artboard: "BinaryDoctor" },
  { href: "/previews", title: "iOS · Preview gallery", artboard: "IosPreviews" },
  { href: "/console/sessions/ses_7f2c91", title: "Cloud · Session replay", artboard: "SessionReplay" },
  { href: "/live", title: "Live device (P0-12 UI, needs irisrun start)", artboard: "none" },
];

// The Console routes and states in the order of the route table in docs/ui-plan.md.
export const consoleEntries: GalleryEntry[] = [
  { href: "/console/hosts", title: "Mac hosts", artboard: "MacHosts" },
  { href: "/console/hosts?mock=empty", title: "Mac hosts · Empty", artboard: "ConsoleStates" },
  { href: "/console/hosts/new", title: "Add Mac host · Connect AWS", artboard: "HostWizardAws" },
  { href: "/console/hosts/new?mock=any-mac", title: "Add Mac host · Any Mac", artboard: "HostWizardAnyMac" },
  { href: "/console/hosts/new?mock=aws-role-failed", title: "Add Mac host · AWS role check failed", artboard: "ConsoleStates" },
  { href: "/console/login", title: "Sign in", artboard: "ConsoleLogin" },
  { href: "/console/login?mock=link-expired", title: "Sign in · Link expired", artboard: "ConsoleStates" },
  { href: "/console/onboarding", title: "Onboarding", artboard: "Onboarding" },
  { href: "/console/projects", title: "Projects", artboard: "Projects" },
  { href: "/console/projects?mock=empty", title: "Projects · Empty", artboard: "ConsoleStates" },
  { href: "/console/devices", title: "Devices", artboard: "Devices" },
  { href: "/console/devices?mock=error", title: "Devices · Error", artboard: "ConsoleStates" },
  { href: "/console/sessions", title: "Sessions", artboard: "Sessions" },
  { href: "/console/sessions?mock=loading", title: "Sessions · Loading", artboard: "ConsoleStates" },
  { href: "/console/members", title: "Members & roles", artboard: "Members" },
  { href: "/console/api-keys", title: "API keys", artboard: "ApiKeys" },
  { href: "/console/api-keys?mock=new-key", title: "API keys · New key", artboard: "ApiKeys" },
  { href: "/console/api-keys?mock=empty", title: "API keys · Empty", artboard: "ConsoleStates" },
  { href: "/console/usage", title: "Usage & billing", artboard: "Usage" },
  { href: "/console/usage?mock=loading", title: "Usage · Loading", artboard: "ConsoleStates" },
  { href: "/console/region", title: "Data region", artboard: "DataRegion" },
  { href: "/console/audit-log", title: "Audit log", artboard: "AuditLog" },
  { href: "/console/audit-log?mock=no-matches", title: "Audit log · No matches", artboard: "ConsoleStates" },
];

export const foundationEntries: GalleryEntry[] = [
  { href: "/screens/foundations", title: "Tokens & components", artboard: "Foundations" },
];
