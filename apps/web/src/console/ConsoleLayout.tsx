import { Link, Outlet } from "@tanstack/react-router";
import {
  ChartColumn,
  ChevronsUpDown,
  Folder,
  Globe,
  History,
  Key,
  Menu,
  ScrollText,
  Server,
  Smartphone,
  Users,
  X,
} from "lucide-react";
import { Fragment, useState } from "react";
import { Avatar } from "../components/ui/avatar";
import { Button } from "../components/ui/button";
import { cn } from "../lib/utils";

const NAV = [
  {
    label: "Workspace",
    items: [
      { to: "/console/projects", label: "Projects", icon: Folder },
      { to: "/console/sessions", label: "Sessions", icon: History },
      { to: "/console/devices", label: "Devices", icon: Smartphone },
      { to: "/console/hosts", label: "Mac hosts", icon: Server },
    ],
  },
  {
    label: "Organization",
    items: [
      { to: "/console/members", label: "Members & roles", icon: Users },
      { to: "/console/api-keys", label: "API keys", icon: Key },
      { to: "/console/usage", label: "Usage & billing", icon: ChartColumn },
      { to: "/console/region", label: "Data region", icon: Globe },
      { to: "/console/audit-log", label: "Audit log", icon: ScrollText },
    ],
  },
] as const;

/** The Console sidebar and the page beside it. Below 768 px the links fold under a menu button. */
export function ConsoleLayout() {
  const [open, setOpen] = useState(false);
  return (
    <div className="flex min-h-screen flex-col bg-background leading-normal md:flex-row">
      {/* The column runs the page's full height; the nav in it stays in view while the page scrolls. */}
      <div className="shrink-0 border-b bg-sidebar md:w-60 md:border-r md:border-b-0">
        <nav aria-label="Console" className="flex flex-col gap-1 p-3 md:sticky md:top-0 md:h-screen md:overflow-y-auto">
          <div className="flex items-center gap-1">
            <button
              type="button"
              className="flex min-w-0 flex-1 cursor-pointer items-center gap-2.5 rounded-lg px-2 py-1.5 text-left hover:bg-accent"
            >
              <Avatar color="#5b5bd6" className="rounded-[7px]">
                AM
              </Avatar>
              <span className="min-w-0 flex-1">
                <span className="block font-semibold">Acme Mobile</span>
                <span className="block text-[11px] text-muted-foreground">Team</span>
              </span>
              <ChevronsUpDown aria-hidden="true" className="size-3.5 shrink-0 text-muted-foreground" />
            </button>
            <Button
              variant="ghost"
              size="icon"
              className="md:hidden"
              aria-label="Menu"
              aria-expanded={open}
              aria-controls="console-nav"
              onClick={() => setOpen(!open)}
            >
              {open ? <X /> : <Menu />}
            </Button>
          </div>
          <div id="console-nav" className={cn("flex-1 flex-col gap-1", open ? "flex" : "hidden md:flex")}>
            {NAV.map((group) => (
              <Fragment key={group.label}>
                <div className="mx-2 mt-3.5 mb-1 text-[11px] font-medium text-muted-foreground">{group.label}</div>
                {group.items.map(({ to, label, icon: Icon }) => (
                  <Link
                    key={to}
                    to={to}
                    onClick={() => setOpen(false)}
                    className="group flex h-8 items-center gap-2.5 rounded-md px-2 text-foreground no-underline hover:bg-accent hover:text-foreground data-[status=active]:bg-accent data-[status=active]:font-medium"
                  >
                    <Icon
                      aria-hidden="true"
                      className="size-4 shrink-0 text-muted-foreground group-data-[status=active]:text-foreground"
                    />
                    {label}
                  </Link>
                ))}
              </Fragment>
            ))}
            <div className="flex-[1_1_24px]" />
            <div className="flex items-center gap-2.5 border-t p-2">
              <Avatar>MT</Avatar>
              <span className="min-w-0 flex-1">
                <span className="block font-medium">Minh Tran</span>
                <span className="block text-[11px] text-muted-foreground">Owner</span>
              </span>
            </div>
          </div>
        </nav>
      </div>
      <main className="flex min-w-0 flex-1 flex-col">
        <Outlet />
      </main>
    </div>
  );
}
