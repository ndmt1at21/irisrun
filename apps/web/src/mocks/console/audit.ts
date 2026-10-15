/** Who made a change: a member, Iris itself or an API key. */
export interface AuditActor {
  name: string;
  initials: string;
  color: string;
  /** Members get a round avatar; Iris and API keys a square one. */
  person: boolean;
}

export type AuditCategory = "Sessions" | "Hosts" | "Keys" | "Members" | "Settings";

/** A value in an event's details that changed; shown red to green. */
export interface AuditChange {
  from: string;
  to: string;
}

/** A row of the audit log. */
export interface AuditEvent {
  id: string;
  /** The event type, e.g. member.role_changed. */
  event: string;
  /** Already formatted in GMT+7, e.g. "Today 21:02". */
  time: string;
  actor: AuditActor;
  action: string;
  /** Sets the dot color: green, blue, red or amber. */
  kind: "create" | "change" | "remove" | "warn";
  category: AuditCategory;
  target: string;
  /** IP and place, or "Iris" for its own events. */
  from: string;
  /** The rest of the event as the API returns it, shown when the row is open. */
  details: Record<string, string | AuditChange>;
}

export const auditCategories: AuditCategory[] = ["Sessions", "Hosts", "Keys", "Members", "Settings"];

const member = (name: string, initials: string, color: string): AuditActor => ({ name, initials, color, person: true });
const minh = member("Minh Tran", "MT", "#5b5bd6");
const linh = member("Linh Pham", "LP", "#0a7a6f");
const rizky = member("Rizky Pratama", "RP", "#24489a");
const iris: AuditActor = { name: "Iris", initials: "IR", color: "#3f3f46", person: false };
const hostKey: AuditActor = { name: "API key · host-automation", initials: "K", color: "#9a4a1c", person: false };

/** Everyone who can show up as an actor, for the Actor filter. */
export const auditActors: AuditActor[] = [
  minh,
  linh,
  member("Arjun Mehta", "AM", "#9a4a1c"),
  rizky,
  member("Somchai K.", "SK", "#7a3590"),
  member("Yuki Sato", "YS", "#1d6a3a"),
  member("Hana Kim", "HK", "#52525b"),
  iris,
  hostKey,
];

const HCM = "203.0.113.24 · Ho Chi Minh City";
const HANOI = "198.51.100.7 · Hanoi";

/** Events matching all filters on the server; the API pages through them. */
export const auditTotal = 412;

/** The first page, newest first. */
export const auditEvents: AuditEvent[] = [
  {
    id: "evt_01JA8T4X2B", event: "host.provisioning_started", time: "Today 21:02", actor: minh,
    action: "Started provisioning host", kind: "create", category: "Hosts", target: "tokyo-m1-01 · mac2.metal", from: HCM,
    details: { host: "tokyo-m1-01", instance: "mac2.metal", region: "ap-northeast-1" },
  },
  {
    id: "evt_01JA8SZ0QH", event: "api_key.created", time: "Today 20:55", actor: minh,
    action: "Created API key", kind: "create", category: "Keys", target: "kedai-scripts", from: HCM,
    details: { key: "kedai-scripts", scopes: "Open sessions · Read devices", expires: "Jan 12, 2027" },
  },
  {
    id: "evt_01JA8Q2M7K", event: "member.role_changed", time: "Today 20:12", actor: linh,
    action: "Changed member role", kind: "change", category: "Members", target: "hana@acme.example", from: HANOI,
    details: { member: "hana@acme.example", role: { from: "Developer", to: "Viewer" }, projects: "all" },
  },
  {
    id: "evt_01JA8NB6RD", event: "host.offline", time: "Today 19:40", actor: iris,
    action: "Host went offline", kind: "warn", category: "Hosts", target: "mini-hn-02 · no heartbeat 5 min", from: "Iris",
    details: { host: "mini-hn-02", last_heartbeat: "19:35" },
  },
  {
    id: "evt_01JA8JW3FE", event: "member.invited", time: "Today 18:03", actor: rizky,
    action: "Invited member", kind: "create", category: "Members", target: "dewi@acme.example · Developer",
    from: "192.0.2.41 · Jakarta",
    details: { email: "dewi@acme.example", role: "Developer", projects: "kedai-android" },
  },
  {
    // A settings change, but the artboard lists it under its Hosts, Keys, Members filter.
    id: "evt_01JA7Y5C1N", event: "region.move_started", time: "Today 11:20", actor: minh,
    action: "Started moving data region", kind: "change", category: "Hosts", target: "Singapore → Tokyo", from: HCM,
    details: { region: { from: "ap-southeast-1", to: "ap-northeast-1" }, data: "41 GB" },
  },
  {
    id: "evt_01JA6E9K4T", event: "host.agent_restarted", time: "Oct 13 09:12", actor: hostKey,
    action: "Restarted agent", kind: "change", category: "Hosts", target: "sg-m2-02", from: "192.0.2.88 · Singapore",
    details: { host: "sg-m2-02", agent: "1.4.2" },
  },
  {
    id: "evt_01JA5R8M2P", event: "member.removed", time: "Oct 12 17:45", actor: linh,
    action: "Removed member", kind: "remove", category: "Members", target: "tuan@acme.example", from: HANOI,
    details: { member: "tuan@acme.example", role: "Developer" },
  },
  {
    id: "evt_01JA51TQ6V", event: "host.added", time: "Oct 12 10:03", actor: minh,
    action: "Added Mac host", kind: "create", category: "Hosts", target: "studio-hcm-01 · Any Mac", from: HCM,
    details: { host: "studio-hcm-01", type: "any_mac" },
  },
];
