export type Role = "Owner" | "Admin" | "Developer" | "Viewer";

export const roles: Role[] = ["Owner", "Admin", "Developer", "Viewer"];

/** A row of the Members table. */
export interface Member {
  name: string;
  initials: string;
  email: string;
  role: Role;
  /** "All projects" or the projects they were added to. */
  projects: string;
  /** Already formatted; null while they are active now. */
  lastActive: string | null;
  /** The avatar color. */
  color: string;
}

/** A row of the Pending invites tab. */
export interface Invite {
  email: string;
  role: Role;
  invitedBy: string;
  /** Already formatted, e.g. "2 days ago". */
  sent: string;
}

/** A row of the "What each role can do" table. */
export interface Permission {
  action: string;
  allowed: Role[];
}

export const members: Member[] = [
  {
    name: "Minh Tran", initials: "MT", email: "minh@acme.example", role: "Owner", projects: "All projects",
    lastActive: null, color: "#5b5bd6",
  },
  {
    name: "Linh Pham", initials: "LP", email: "linh@acme.example", role: "Admin", projects: "All projects",
    lastActive: "5 min ago", color: "#0a7a6f",
  },
  {
    name: "Arjun Mehta", initials: "AM", email: "arjun@acme.example", role: "Developer", projects: "kedai-ios",
    lastActive: null, color: "#9a4a1c",
  },
  {
    name: "Rizky Pratama", initials: "RP", email: "rizky@acme.example", role: "Developer",
    projects: "kedai-android, kedai-seller-android", lastActive: "1 h ago", color: "#24489a",
  },
  {
    name: "Somchai K.", initials: "SK", email: "somchai@acme.example", role: "Developer", projects: "kedai-android",
    lastActive: "Yesterday", color: "#7a3590",
  },
  {
    name: "Yuki Sato", initials: "YS", email: "yuki@acme.example", role: "Developer", projects: "kedai-ios",
    lastActive: "Oct 12", color: "#1d6a3a",
  },
  {
    name: "Hana Kim", initials: "HK", email: "hana@acme.example", role: "Viewer", projects: "All projects",
    lastActive: "Oct 3", color: "#52525b",
  },
];

export const invites: Invite[] = [
  { email: "dewi@acme.example", role: "Developer", invitedBy: "Minh Tran", sent: "2 days ago" },
  { email: "tuan@acme.example", role: "Viewer", invitedBy: "Linh Pham", sent: "Oct 9" },
];

export const permissions: Permission[] = [
  { action: "Open sessions", allowed: ["Owner", "Admin", "Developer"] },
  { action: "Watch replays", allowed: ["Owner", "Admin", "Developer", "Viewer"] },
  { action: "Manage Mac hosts", allowed: ["Owner", "Admin"] },
  { action: "Create API keys", allowed: ["Owner", "Admin", "Developer"] },
  { action: "Manage members", allowed: ["Owner", "Admin"] },
  { action: "Billing & data region", allowed: ["Owner"] },
];
