import { Link } from "@tanstack/react-router";
import { Folder, Plus } from "lucide-react";
import { useState } from "react";
import { Badge, Tag } from "../../components/ui/badge";
import { Button } from "../../components/ui/button";
import { Card } from "../../components/ui/card";
import { EmptyState } from "../../components/ui/empty-state";
import { SearchField } from "../../components/ui/search-field";
import { Segmented, SegmentedItem } from "../../components/ui/segmented";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../components/ui/select";
import { useMock } from "../../lib/mock";
import { type Project, projects } from "../../mocks/console/projects";

export function ProjectsPage() {
  const all = useMock() === "empty" ? [] : projects;
  const [query, setQuery] = useState("");
  const [platform, setPlatform] = useState("all");
  const [sort, setSort] = useState("last-active");
  const q = query.trim().toLowerCase();
  const shown = all.filter(
    (p) => (platform === "all" || p.platform === platform) && `${p.name} ${p.repo}`.toLowerCase().includes(q),
  );
  // The data comes most recently active first, so only Name needs sorting.
  if (sort === "name") shown.sort((a, b) => a.name.localeCompare(b.name));

  return (
    <div className="flex w-full max-w-[1200px] flex-col gap-[18px] p-7">
      <div className="flex flex-wrap items-end gap-3">
        <div className="flex-[1_1_320px]">
          <h1 className="text-[22px] font-semibold tracking-[-0.02em]">Projects</h1>
          <p className="mt-1 text-muted-foreground">
            Apps your team runs with Iris. A project is created the first time someone runs{" "}
            <span className="font-mono text-foreground">irisrun start</span> in a repo.
          </p>
        </div>
        <Button size="lg">
          <Plus className="size-[15px]" strokeWidth={2.2} />
          Link a repo
        </Button>
      </div>

      {all.length === 0 ? (
        <EmptyState
          className="min-h-[280px] rounded-[10px] border border-dashed border-input"
          icon={<Folder />}
          title="No projects yet"
          description="Run this in your app’s repo. The project shows up here after the first start."
        >
          <code className="rounded-md bg-muted px-2.5 py-1.5 font-mono text-xs">irisrun start --org acme-mobile</code>
        </EmptyState>
      ) : (
        <>
          <div className="flex flex-wrap gap-2">
            <SearchField
              aria-label="Search projects"
              placeholder="Search projects"
              className="box-content flex-[0_1_300px]"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
            />
            <Segmented aria-label="Platform" value={platform} onValueChange={setPlatform}>
              <SegmentedItem value="all">All</SegmentedItem>
              <SegmentedItem value="Android">Android</SegmentedItem>
              <SegmentedItem value="iOS">iOS</SegmentedItem>
            </Segmented>
            <span className="flex-1" />
            <Select value={sort} onValueChange={setSort}>
              <SelectTrigger aria-label="Sort">
                <span>
                  Sort: <SelectValue />
                </span>
              </SelectTrigger>
              <SelectContent align="end">
                <SelectItem value="last-active">Last active</SelectItem>
                <SelectItem value="name">Name</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="grid grid-cols-[repeat(auto-fill,minmax(min(420px,100%),1fr))] gap-3.5">
            {shown.map((project) => (
              <ProjectCard key={project.name} project={project} />
            ))}
          </div>
        </>
      )}
    </div>
  );
}

function ProjectCard({ project: p }: { project: Project }) {
  return (
    <Card role="article" className="flex flex-col gap-3 p-4">
      <div className="flex items-start gap-3">
        <span
          className="inline-flex size-9 shrink-0 items-center justify-center rounded-[9px] font-semibold text-white"
          style={{ background: p.tint }}
        >
          {p.initial}
        </span>
        <div className="min-w-0 flex-1">
          {/* No project page yet: the link stays here, like the design's `#project`. */}
          <Link to="." search hash="project" className="block text-sm font-semibold text-foreground no-underline">
            {p.name}
          </Link>
          <span className="block truncate font-mono text-xs text-muted-foreground">{p.repo}</span>
        </div>
        {p.running > 0 ? (
          <Badge tone="success" dot className="text-[11.5px]">
            {p.running} running
          </Badge>
        ) : (
          <Badge tone={p.lastActive ? "muted" : "primary"} className="text-[11.5px]">
            {p.lastActive ? "Idle" : "New"}
          </Badge>
        )}
      </div>
      <div className="flex flex-wrap gap-1.5">
        {[p.platform, p.framework].map((tag) => (
          <Tag key={tag} className="h-6 px-2 text-[11.5px]">
            {tag}
          </Tag>
        ))}
      </div>
      <div className="grid grid-cols-3 gap-2 border-t pt-3 text-xs">
        <div>
          <div className="text-muted-foreground">Sessions · 7 days</div>
          <div className="text-sm font-semibold">{p.sessions7d}</div>
        </div>
        <div>
          <div className="text-muted-foreground">Default device</div>
          <div className="font-medium">{p.defaultDevice ?? "Not set"}</div>
        </div>
        <div>
          <div className="text-muted-foreground">Last active</div>
          <div className="font-medium">{p.lastActive ?? "Never opened"}</div>
        </div>
      </div>
    </Card>
  );
}
