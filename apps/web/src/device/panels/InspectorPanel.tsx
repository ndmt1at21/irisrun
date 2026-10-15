import { ExternalLink, GripHorizontal, LoaderCircle, RefreshCw, SquareMousePointer, TriangleAlert } from "lucide-react";
import { type KeyboardEvent, type ReactNode, useRef, useState } from "react";
import { Tag } from "../../components/ui/badge";
import { Button } from "../../components/ui/button";
import { EmptyState } from "../../components/ui/empty-state";
import { SearchField } from "../../components/ui/search-field";
import { Skeleton } from "../../components/ui/skeleton";
import { Switch } from "../../components/ui/switch";
import { cn } from "../../lib/utils";
import { kedaiSelectedView, kedaiViews, type ViewNode } from "../../mocks/device/inspector";
import { TabBarSlot } from "../shell/tabBar";

const SKELETON: [depth: number, width: number][] = [
  [0, 60],
  [1, 90],
  [2, 70],
  [3, 110],
  [3, 80],
  [4, 96],
  [4, 64],
  [3, 88],
  [2, 72],
];
const PARENTS = new Set(kedaiViews.filter((view, index) => (kedaiViews[index + 1]?.depth ?? 0) > view.depth).map(({ id }) => id));
const TREE_HEIGHT: [min: number, start: number, max: number] = [88, 326, 640];
const STEPS: Record<string, number> = { ArrowUp: -16, ArrowDown: 16 };

/** The selected view and the one under the pointer; a scenario shares it with the device screen to draw outlines. */
export function useViewSelection(initial: { selected?: string; hovered?: string } = {}) {
  const [selected, select] = useState(initial.selected ?? kedaiSelectedView);
  const [hovered, hover] = useState(initial.hovered);
  return { selected, select, hovered, hover };
}

export type ViewSelection = ReturnType<typeof useViewSelection>;

/** What the tree shows: views whose ancestors are all expanded or, while finding, the matches and their ancestors. */
function treeRows(views: ViewNode[], collapsed: Set<string>, query: string): ViewNode[] {
  const needle = query.trim().toLowerCase();
  if (needle) {
    const keep = new Set<ViewNode>();
    views.forEach((view, index) => {
      if (!`${view.type} ${view.detail ?? ""}`.toLowerCase().includes(needle)) return;
      for (let i = index, depth = view.depth + 1; i >= 0 && depth > 0; i--) {
        const ancestor = views[i];
        if (ancestor && ancestor.depth < depth) {
          keep.add(ancestor);
          depth = ancestor.depth;
        }
      }
    });
    return views.filter((view) => keep.has(view));
  }
  let hidden = Infinity;
  return views.filter((view) => {
    if (view.depth > hidden) return false;
    hidden = collapsed.has(view.id) ? view.depth : Infinity;
    return true;
  });
}

/**
 * The Inspector panel: the app's view tree and the selected view's properties.
 * `state` is a PanelStates state, `loading` or `unavailable`; `selection` lets
 * the device screen follow the tree.
 */
export function InspectorPanel({ state, selection }: { state?: string; selection?: ViewSelection }) {
  const own = useViewSelection();
  const { selected, select, hovered, hover } = selection ?? own;
  const [picking, setPicking] = useState(true);
  const [bounds, setBounds] = useState(false);
  const [query, setQuery] = useState("");
  const [collapsed, setCollapsed] = useState(() => new Set(kedaiViews.filter((view) => view.collapsed).map(({ id }) => id)));
  const [treeHeight, setTreeHeight] = useState(TREE_HEIGHT[1]);
  const [flags, setFlags] = useState<Record<string, boolean>>({});
  const drag = useRef<{ from: number; height: number } | null>(null);

  if (state === "loading") {
    return (
      <>
        <TabBarSlot>
          <span className="ml-auto inline-flex items-center gap-1.5 text-xs text-muted-foreground">
            <LoaderCircle className="size-3 animate-spin" strokeWidth={3} />
            Reading view tree
          </span>
        </TabBarSlot>
        <div aria-busy="true" className="flex flex-col gap-2.5 p-3">
          {SKELETON.map(([depth, width], index) => (
            <div key={index} className="flex items-center gap-2" style={{ paddingLeft: depth * 14 }}>
              <Skeleton className="size-2.5 rounded-[3px]" />
              <Skeleton className="h-[9px]" style={{ width }} />
            </div>
          ))}
        </div>
      </>
    );
  }

  if (state === "unavailable") {
    return (
      <EmptyState
        className="flex-1"
        tone="warning"
        icon={<TriangleAlert />}
        title="Can’t read the view tree on this device"
        description="Real devices need a debug build with the Iris inspector library. Add it once and rebuild."
        actions={
          <>
            <Button size="xs">Show setup</Button>
            <Button variant="outline" size="xs" className="font-normal">
              Try again
            </Button>
          </>
        }
      />
    );
  }

  const rows = treeRows(kedaiViews, collapsed, query);
  const finding = query.trim() !== "";
  const isOpen = (id: string) => PARENTS.has(id) && (finding || !collapsed.has(id));
  const focus = rows.some(({ id }) => id === selected) ? selected : rows[0]?.id;
  const view = kedaiViews.find(({ id }) => id === selected);
  const toggle = (id: string) => {
    const next = new Set(collapsed);
    if (!next.delete(id)) next.add(id);
    setCollapsed(next);
  };
  const resize = (height: number) => setTreeHeight(Math.round(Math.min(TREE_HEIGHT[2], Math.max(TREE_HEIGHT[0], height))));

  // Arrow keys move the selection, as in Xcode's view debugger; Left and Right also collapse and expand.
  const onTreeKey = (event: KeyboardEvent<HTMLElement>) => {
    const index = rows.findIndex(({ id }) => id === focus);
    const row = rows[index];
    if (!row) return;
    const open = isOpen(row.id);
    let next: ViewNode | undefined;
    switch (event.key) {
      case "ArrowDown":
        next = rows[index + 1];
        break;
      case "ArrowUp":
        next = rows[index - 1];
        break;
      case "Home":
        next = rows[0];
        break;
      case "End":
        next = rows.at(-1);
        break;
      case "ArrowRight":
        if (PARENTS.has(row.id) && !open) toggle(row.id);
        else if ((rows[index + 1]?.depth ?? 0) > row.depth) next = rows[index + 1];
        break;
      case "ArrowLeft":
        if (open) toggle(row.id);
        else next = rows.slice(0, index).findLast(({ depth }) => depth < row.depth);
        break;
      default:
        return;
    }
    event.preventDefault();
    if (!next) return;
    select(next.id);
    event.currentTarget.querySelector<HTMLElement>(`[data-view="${next.id}"]`)?.focus();
  };

  return (
    <>
      <div className="flex items-center gap-2 border-b px-3 py-2">
        <Button
          variant="outline"
          size="sm"
          aria-pressed={picking}
          title="Select a view on the device"
          onClick={() => setPicking(!picking)}
          className="px-2.5 text-xs aria-pressed:border-primary/45 aria-pressed:bg-selection aria-pressed:text-link"
        >
          <SquareMousePointer className="size-3.5" />
          Select
        </Button>
        <SearchField
          aria-label="Find view"
          placeholder="Find view by type or text"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          className="flex-1 text-xs"
        />
        <label className="inline-flex items-center gap-2 text-xs whitespace-nowrap text-muted-foreground">
          <Switch aria-label="Show layout bounds" checked={bounds} onCheckedChange={setBounds} />
          Bounds
        </label>
        <Button variant="ghost" size="icon-xs" aria-label="Refresh view tree">
          <RefreshCw className="size-[15px]" />
        </Button>
      </div>
      <div
        role="tree"
        aria-label="View hierarchy"
        style={{ height: treeHeight }}
        className="min-h-[88px] shrink overflow-auto py-1 font-mono text-xs leading-[22px]"
        onKeyDown={onTreeKey}
        onMouseLeave={() => hover(undefined)}
      >
        {rows.map((row) => {
          const parent = PARENTS.has(row.id);
          const open = isOpen(row.id);
          const current = row.id === selected;
          return (
            <div
              key={row.id}
              role="treeitem"
              aria-level={row.depth + 1}
              aria-expanded={parent ? open : undefined}
              aria-selected={current}
              tabIndex={row.id === focus ? 0 : -1}
              data-view={row.id}
              style={{ paddingLeft: 10 + row.depth * 14 }}
              className={cn(
                "flex cursor-default items-center gap-1 pr-3 whitespace-nowrap focus-visible:-outline-offset-2",
                current ? "bg-selection" : row.id === hovered && "bg-accent",
              )}
              onClick={() => select(row.id)}
              onMouseEnter={() => hover(row.id)}
            >
              <span
                aria-hidden="true"
                className="w-3 shrink-0 text-center text-[10px] text-muted-foreground"
                onClick={(event) => {
                  if (!parent) return;
                  event.stopPropagation();
                  toggle(row.id);
                }}
              >
                {parent && (open ? "▾" : "▸")}
              </span>
              <span className={cn("font-medium", current && "text-link")}>{row.type}</span>
              {row.detail && <span className="truncate text-muted-foreground">{row.detail}</span>}
            </div>
          );
        })}
        {rows.length === 0 && <p className="px-3 font-sans text-muted-foreground">No views match “{query.trim()}”</p>}
      </div>
      <div
        role="separator"
        aria-orientation="horizontal"
        aria-label="Resize properties"
        aria-valuenow={treeHeight}
        aria-valuemin={TREE_HEIGHT[0]}
        aria-valuemax={TREE_HEIGHT[2]}
        tabIndex={0}
        onPointerDown={(event) => {
          event.preventDefault();
          event.currentTarget.setPointerCapture(event.pointerId);
          drag.current = { from: event.clientY, height: treeHeight };
        }}
        onPointerMove={(event) => drag.current && resize(drag.current.height + event.clientY - drag.current.from)}
        onPointerUp={() => (drag.current = null)}
        onKeyDown={(event) => {
          const step = STEPS[event.key];
          if (!step) return;
          event.preventDefault();
          resize(treeHeight + step);
        }}
        className="relative z-10 flex h-px shrink-0 cursor-row-resize touch-none items-center justify-center bg-border before:absolute before:inset-x-0 before:-inset-y-1"
      >
        <span className="relative flex h-3 w-[18px] items-center justify-center rounded-[3px] bg-border text-muted-foreground">
          <GripHorizontal className="size-2.5" />
        </span>
      </div>
      {view && (
        <div className="min-h-0 flex-1 overflow-auto p-3">
          <div className="mb-3 flex items-center gap-2">
            <span className="text-sm font-semibold">{view.type}</span>
            <Tag>{view.kind ?? "SwiftUI View"}</Tag>
            <span className="flex-1" />
            {view.source && (
              <Button variant="link" className="h-auto gap-[5px] px-0 font-mono text-xs font-normal">
                <ExternalLink className="size-[13px]" />
                {view.source}
              </Button>
            )}
          </div>
          <Section title="Frame">
            <dl className="grid grid-cols-4 gap-1.5 font-mono text-xs">
              {(["X", "Y", "W", "H"] as const).map((axis, index) => (
                <div key={axis} className="flex h-7 items-center gap-2 rounded-md bg-muted px-2">
                  <dt className="text-muted-foreground">{axis}</dt>
                  <dd>{view.frame[index]}</dd>
                </div>
              ))}
            </dl>
          </Section>
          {view.modifiers && (
            <Section title="Modifiers">
              <pre className="overflow-x-auto rounded-md border px-2.5 py-2 font-mono text-xs leading-5">{view.modifiers.join("\n")}</pre>
            </Section>
          )}
          {view.state && (
            <Section title="State">
              <dl className="grid grid-cols-[120px_minmax(0,1fr)] items-center gap-x-3 gap-y-1.5 font-mono text-xs">
                {view.state.map(({ name, value }) => {
                  const key = `${view.id} ${name}`;
                  const on = flags[key] ?? value;
                  return (
                    <Pair key={name} label={name}>
                      {typeof on === "boolean" ? (
                        <span className="inline-flex items-center gap-2">
                          <Switch
                            aria-label={name.split(" ").at(-1)}
                            checked={on}
                            onCheckedChange={(checked) => setFlags({ ...flags, [key]: checked })}
                          />
                          {String(on)}
                        </span>
                      ) : (
                        <span className="block truncate">{on}</span>
                      )}
                    </Pair>
                  );
                })}
              </dl>
            </Section>
          )}
          {view.accessibility && (
            <Section title="Accessibility">
              <dl className="grid grid-cols-[120px_minmax(0,1fr)] gap-x-3 gap-y-1.5 text-xs">
                <Pair label="Label">{view.accessibility.label}</Pair>
                {view.accessibility.traits && (
                  <Pair label="Traits">
                    <span className="font-mono">{view.accessibility.traits}</span>
                  </Pair>
                )}
              </dl>
            </Section>
          )}
        </div>
      )}
    </>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="mb-3.5 last:mb-0">
      <h3 className="mb-1.5 text-[11px] font-medium text-muted-foreground">{title}</h3>
      {children}
    </section>
  );
}

function Pair({ label, children }: { label: string; children: ReactNode }) {
  return (
    <>
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="min-w-0">{children}</dd>
    </>
  );
}
