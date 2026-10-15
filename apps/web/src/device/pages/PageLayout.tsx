import { Link } from "@tanstack/react-router";
import { Smartphone } from "lucide-react";
import type { ReactNode } from "react";
import { IrisLogo } from "../../components/IrisLogo";
import { RunStatusBadge } from "../../components/RunStatusBadge";
import { ThemeToggle } from "../../components/ThemeToggle";
import { TopBar } from "../../components/TopBar";
import { Button } from "../../components/ui/button";

/** A full page opened from the tool panel: the project, "Back to device", then the page. */
export function PageLayout({ project, target, children }: { project: string; target: string; children: ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col">
      <TopBar>
        <div className="flex items-center gap-2">
          <IrisLogo />
          <span className="text-sm font-semibold tracking-[-0.01em]">Iris</span>
        </div>
        <div aria-hidden="true" className="h-5 w-px bg-border" />
        <span className="font-medium">
          {project}
          <span className="font-normal text-muted-foreground"> / {target}</span>
        </span>
        <RunStatusBadge status="running" />
        <div className="flex-1" />
        <Button asChild variant="outline" size="sm" className="h-8 px-2.5 text-xs">
          <Link to="/">
            <Smartphone className="size-3.5" />
            Back to device
          </Link>
        </Button>
        <ThemeToggle />
      </TopBar>
      <main className="flex-auto overflow-auto">{children}</main>
    </div>
  );
}
