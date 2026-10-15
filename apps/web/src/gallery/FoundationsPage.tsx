import { Camera, Check, Cloud, Folder, Laptop, LoaderCircle, RefreshCw, Smartphone } from "lucide-react";
import type { ReactNode } from "react";
import { IrisLogo } from "../components/IrisLogo";
import { LatencyChip } from "../components/LatencyChip";
import { LevelChip } from "../components/LevelChip";
import { RunStatusBadge } from "../components/RunStatusBadge";
import { ThemeToggle } from "../components/ThemeToggle";
import { Alert, AlertDescription, AlertTitle } from "../components/ui/alert";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "../components/ui/alert-dialog";
import { Avatar } from "../components/ui/avatar";
import { Badge, Tag } from "../components/ui/badge";
import { Button } from "../components/ui/button";
import { Card } from "../components/ui/card";
import { Checkbox } from "../components/ui/checkbox";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "../components/ui/dialog";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "../components/ui/dropdown-menu";
import { EmptyState } from "../components/ui/empty-state";
import { Input } from "../components/ui/input";
import { Kbd } from "../components/ui/kbd";
import { Popover, PopoverContent, PopoverTrigger } from "../components/ui/popover";
import { Progress } from "../components/ui/progress";
import { RadioGroup, RadioGroupItem } from "../components/ui/radio-group";
import { SearchField } from "../components/ui/search-field";
import { Segmented, SegmentedItem } from "../components/ui/segmented";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../components/ui/select";
import { Skeleton } from "../components/ui/skeleton";
import { Switch } from "../components/ui/switch";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";
import { Tabs, TabsList, TabsTrigger } from "../components/ui/tabs";
import { Textarea } from "../components/ui/textarea";
import { ToggleGroup, ToggleGroupItem } from "../components/ui/toggle-group";
import type { Theme } from "../lib/theme";
import { cn } from "../lib/utils";

// [token, light, dark]. The first 16 are the ones the Foundations artboard lists;
// the rest appear only in some artboards.
const TOKENS: [string, string, string][] = [
  ["--background", "#ffffff", "#09090b"],
  ["--foreground", "#09090b", "#fafafa"],
  ["--card", "#ffffff", "#111114"],
  ["--muted", "#f4f4f5", "#1c1c20"],
  ["--muted-foreground", "#63636b", "#a1a1aa"],
  ["--border", "#e4e4e7", "#27272a"],
  ["--input", "#e4e4e7", "#2e2e33"],
  ["--primary", "#5b5bd6", "#5b5bd6"],
  ["--primary-foreground", "#ffffff", "#ffffff"],
  ["--accent", "#f4f4f5", "#1f1f24"],
  ["--destructive", "#dc2626", "#f87171"],
  ["--success", "#15803d", "#4ade80"],
  ["--warning", "#b45309", "#fbbf24"],
  ["--info", "#2563eb", "#60a5fa"],
  ["--link", "#4f4cc4", "#b1a9ff"],
  ["--selection", "#ebebfd", "#1f1d44"],
  ["--popover", "#ffffff", "#111114"],
  ["--ring", "#5b5bd6", "#8b8bf2"],
  ["--stage", "#ededf0", "#050507"],
  ["--code", "#fafafa", "#050507"],
  ["--sidebar", "#fafafa", "#0c0c0e"],
  ["--side", "#f4f4f5", "#0f0f12"],
  ["--skeleton", "#ececef", "#1f1f24"],
  ["--overlay", "rgba(9,9,11,.45)", "rgba(0,0,0,.7)"],
  ["--series-1", "#5b5bd6", "#7c7cf0"],
  ["--series-2", "#e08a1e", "#f5b04a"],
  ["--grid", "#ececef", "#1f1f24"],
];

const mono = "font-mono text-[11.5px]";

/** Route `/screens/foundations`: the Foundations artboard built from the real tokens and components. */
export function FoundationsPage() {
  return (
    <div className="min-h-screen bg-background leading-normal text-foreground">
      <div className="mx-auto flex max-w-[1360px] flex-col gap-9 px-4 py-9 sm:px-7">
        <header className="flex flex-wrap items-center gap-3">
          <IrisLogo size={28} />
          <h1 className="text-[26px] font-semibold tracking-[-0.02em]">Iris · tokens &amp; components</h1>
          <Badge tone="outline">shadcn/ui variables · Tailwind</Badge>
          <ThemeToggle className="ml-auto" />
        </header>

        <section aria-labelledby="f-color">
          <h2 id="f-color" className="mb-3.5 text-base font-semibold">
            Color tokens
          </h2>
          <div className="grid grid-cols-[repeat(auto-fit,minmax(min(560px,100%),1fr))] gap-4">
            <TokenPanel theme="light" />
            <TokenPanel theme="dark" />
          </div>
        </section>

        <section aria-labelledby="f-type">
          <h2 id="f-type" className="mb-3.5 text-base font-semibold">
            Type
          </h2>
          <div className="grid grid-cols-[repeat(auto-fit,minmax(min(300px,100%),1fr))] gap-3">
            <TypeSample note="Geist 22 / 600 · −2%">
              <div className="text-[22px] font-semibold tracking-[-0.02em]">Page title</div>
            </TypeSample>
            <TypeSample note="Geist 14–15 / 600">
              <div className="text-[15px] font-semibold">Section · panel title</div>
            </TypeSample>
            <TypeSample note="Geist 13 / 400 · line 1.45">
              <div>Body and controls in tool panels</div>
            </TypeSample>
            <TypeSample note="Geist Mono 11.5 · logs, code, IDs">
              <div className={mono}>21:04:12.611 D OkHttp &lt;-- 200 OK</div>
            </TypeSample>
          </div>
        </section>

        <section aria-labelledby="f-comp">
          <h2 id="f-comp" className="mb-3.5 text-base font-semibold">
            Components
          </h2>
          <div className="grid grid-cols-[repeat(auto-fit,minmax(min(400px,100%),1fr))] gap-3.5">
            <Specimen label="Button">
              <div className="flex flex-wrap items-center gap-2">
                <Button>Default</Button>
                <Button variant="outline">Outline</Button>
                <Button variant="secondary">Secondary</Button>
                <Button variant="ghost">Ghost</Button>
                <Button variant="destructive">End session</Button>
                <Button variant="ghost" size="icon" aria-label="Take screenshot">
                  <Camera />
                </Button>
              </div>
            </Specimen>

            <Specimen label="Run status badge">
              <div className="flex flex-wrap gap-2">
                <RunStatusBadge status="running" />
                <RunStatusBadge status="paused" />
                <RunStatusBadge status="setting-up" />
                <RunStatusBadge status="reconnecting" />
                <RunStatusBadge status="build-failed" />
                <RunStatusBadge status="building" />
                <RunStatusBadge status="waiting" />
              </div>
            </Specimen>

            <Specimen label="Tabs · Toggle group">
              <Tabs defaultValue="logs">
                <TabsList aria-label="Example tabs">
                  <TabsTrigger value="logs">Logs</TabsTrigger>
                  <TabsTrigger value="network">Network</TabsTrigger>
                  <TabsTrigger value="inspector">Inspector</TabsTrigger>
                </TabsList>
              </Tabs>
              <ToggleGroup aria-label="Log levels" defaultValue={["info", "error"]}>
                <ToggleGroupItem value="verbose">Verbose</ToggleGroupItem>
                <ToggleGroupItem value="info">Info</ToggleGroupItem>
                <ToggleGroupItem value="error">Error</ToggleGroupItem>
              </ToggleGroup>
            </Specimen>

            <Specimen label="Log level chip">
              <div className="flex gap-2">
                {(["V", "D", "I", "W", "E", "P"] as const).map((level) => (
                  <LevelChip key={level} level={level} className="size-[18px]" />
                ))}
              </div>
              <div className="text-xs font-medium text-muted-foreground">Hot reload</div>
              <div className="flex flex-wrap gap-2 text-xs">
                <span className="inline-flex h-7 items-center gap-1.5 rounded-full border border-[color-mix(in_srgb,var(--primary)_35%,var(--border))] px-2.5">
                  <LoaderCircle aria-hidden="true" className="size-[13px] animate-spin text-primary" strokeWidth={2.4} />
                  Rebuilding…
                </span>
                <span className="inline-flex h-7 items-center gap-1.5 rounded-full border px-2.5">
                  <Check aria-hidden="true" className="size-[13px] text-success" strokeWidth={2.4} />
                  Updated · 412 ms
                </span>
                <span className="inline-flex h-7 items-center gap-1.5 rounded-full border border-[color-mix(in_srgb,var(--destructive)_40%,var(--border))] px-2.5 text-destructive">
                  ✕ Reload failed · 2 errors
                </span>
              </div>
            </Specimen>

            <Specimen label="Inputs">
              <SearchField aria-label="Search" placeholder="Search" />
              <div className="flex flex-wrap items-center gap-4 text-[12.5px]">
                <Select>
                  <SelectTrigger aria-label="Example select" className="data-[placeholder]:text-foreground">
                    <SelectValue placeholder="Select" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="pixel-8">Pixel 8</SelectItem>
                    <SelectItem value="pixel-fold">Pixel Fold</SelectItem>
                    <SelectItem value="galaxy-s24">Galaxy S24</SelectItem>
                  </SelectContent>
                </Select>
                <label className="inline-flex items-center gap-2">
                  <Switch defaultChecked />
                  Switch
                </label>
                <label className="inline-flex items-center gap-2">
                  <Checkbox defaultChecked />
                  Checkbox
                </label>
              </div>
              <Progress aria-label="Progress example" value={41} />
            </Specimen>

            <Specimen label="Alert" className="gap-2.5">
              <Alert variant="info" role="note" className="block px-3 py-2.5 text-[12.5px]">
                <span className="font-semibold">Info · needs cloud.</span> Calm, used for unsupported APIs and binaries.
              </Alert>
              <Alert variant="warning" role="note" className="block px-3 py-2.5 text-[12.5px]">
                <span className="font-semibold">Warning · costs or connection.</span> 24 h billing, reconnecting.
              </Alert>
              <Alert variant="destructive" role="note" className="block px-3 py-2.5 text-[12.5px]">
                <span className="font-semibold">Error · something broke.</span> Build failed, stream stopped.
              </Alert>
            </Specimen>

            <Specimen label="Latency chip">
              <div className="flex flex-wrap gap-2">
                <LatencyChip ms={38} />
                <LatencyChip ms={142} />
                <LatencyChip ms={310} />
                <LatencyChip />
              </div>
              <div className="text-xs text-muted-foreground">Under 80 ms · 80–200 ms · over 200 ms · offline</div>
            </Specimen>
          </div>
        </section>

        <MoreComponents />
      </div>
    </div>
  );
}

/** Swatches resolved from the CSS variables, so a wrong token shows up next to its expected value. */
function TokenPanel({ theme }: { theme: Theme }) {
  return (
    <div className={cn(theme, "rounded-xl border bg-background p-4 text-foreground")}>
      <div className="mb-3 font-semibold">{theme === "light" ? "Light" : "Dark"}</div>
      <div className="grid grid-cols-[repeat(auto-fill,minmax(150px,1fr))] gap-2.5">
        {TOKENS.map(([name, light, dark]) => (
          <div key={name} className="flex items-center gap-2.5">
            <span
              className={cn(
                "size-8 shrink-0 rounded-lg",
                theme === "light"
                  ? "shadow-[inset_0_0_0_1px_rgba(9,9,11,.12)]"
                  : "shadow-[inset_0_0_0_1px_rgba(255,255,255,.14)]",
              )}
              style={{ background: `var(${name})` }}
            />
            <span className="min-w-0">
              <span className={cn("block", mono)}>{name}</span>
              <span className="block font-mono text-[11px] text-muted-foreground">{theme === "light" ? light : dark}</span>
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

function TypeSample({ note, children }: { note: string; children: ReactNode }) {
  return (
    <div className="rounded-[10px] border p-4">
      {children}
      <div className={cn(mono, "text-muted-foreground")}>{note}</div>
    </div>
  );
}

function Specimen({ label, className, children }: { label: string; className?: string; children: ReactNode }) {
  return (
    <div className={cn("flex flex-col gap-3 rounded-[10px] border p-4", className)}>
      <div className="text-xs font-medium text-muted-foreground">{label}</div>
      {children}
    </div>
  );
}

/** Primitives the artboard doesn't show, styled after the artboards that use them. */
function MoreComponents() {
  return (
    <section aria-labelledby="f-more">
      <h2 id="f-more" className="mb-3.5 text-base font-semibold">
        More components
      </h2>
      <div className="grid grid-cols-[repeat(auto-fit,minmax(min(400px,100%),1fr))] gap-3.5">
        <Specimen label="Segmented · Button sizes">
          <Segmented aria-label="Run target" defaultValue="local">
            <SegmentedItem value="local">
              <Laptop />
              Local
            </SegmentedItem>
            <SegmentedItem value="cloud">
              <Cloud />
              Cloud
            </SegmentedItem>
            <SegmentedItem value="device">
              <Smartphone />
              Real device
            </SegmentedItem>
          </Segmented>
          <div className="flex flex-wrap items-center gap-2">
            <Button size="xs" variant="outline">
              xs 28
            </Button>
            <Button size="sm" variant="outline">
              sm 30
            </Button>
            <Button variant="outline">default 32</Button>
            <Button size="lg" variant="outline">
              lg 34
            </Button>
            <Button size="xl">xl 40</Button>
            <Button size="sm">
              <RefreshCw />
              Retry build
              <Kbd>⌘R</Kbd>
            </Button>
            <Button variant="link">Link</Button>
          </div>
        </Specimen>

        <Specimen label="Badge · Tag · Avatar">
          <div className="flex flex-wrap gap-2">
            <Badge tone="success" dot>
              Online
            </Badge>
            <Badge tone="warning">Waiting</Badge>
            <Badge tone="destructive">✕ Won’t run</Badge>
            <Badge tone="info" dot>
              Provisioning
            </Badge>
            <Badge tone="primary">Iris</Badge>
            <Badge dot>Offline</Badge>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <Tag className="font-mono">android-sdk-license</Tag>
            <Tag className="bg-background font-medium">Managed by Iris</Tag>
            <Avatar color="#5b5bd6" className="rounded-[7px]">
              AM
            </Avatar>
            <Avatar>MT</Avatar>
            <Avatar color="#0f766e" className="size-[30px]">
              HK
            </Avatar>
          </div>
        </Specimen>

        <Specimen label="Input · Textarea">
          <Input aria-label="Host name prefix" defaultValue="sg-m2" className="font-mono" />
          <Textarea aria-label="Payload" rows={3} defaultValue={'{ "orderId": "KD-20931" }'} className="font-mono text-[11.5px]" />
        </Specimen>

        <Specimen label="Radio group">
          <RadioGroup aria-label="Instance type" defaultValue="m2" className="w-full grid-cols-2">
            <RadioGroupItem value="m1">
              <span className="block font-semibold">Apple M1</span>
              <span className={cn("block text-muted-foreground", mono)}>mac2.metal</span>
            </RadioGroupItem>
            <RadioGroupItem value="m2">
              <span className="block font-semibold">Apple M2</span>
              <span className={cn("block text-muted-foreground", mono)}>mac2-m2.metal</span>
            </RadioGroupItem>
          </RadioGroup>
        </Specimen>

        <Specimen label="Table">
          <div className="w-full overflow-hidden rounded-[10px] border">
            <Table aria-label="Mac hosts">
              <TableHeader>
                <TableRow>
                  <TableHead>Host</TableHead>
                  <TableHead>Region</TableHead>
                  <TableHead>Status</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                <TableRow>
                  <TableCell className="font-mono font-medium">sg-m2-01</TableCell>
                  <TableCell>Singapore</TableCell>
                  <TableCell>
                    <Badge tone="success" dot>
                      Online
                    </Badge>
                  </TableCell>
                </TableRow>
                <TableRow>
                  <TableCell className="font-mono font-medium">mini-hn-02</TableCell>
                  <TableCell>Hanoi</TableCell>
                  <TableCell>
                    <Badge dot>Offline</Badge>
                  </TableCell>
                </TableRow>
              </TableBody>
            </Table>
          </div>
        </Specimen>

        <Specimen label="Skeleton · Empty state">
          <div aria-busy="true" className="flex w-full flex-col gap-2.5">
            {[180, 120, 220].map((width) => (
              <div key={width} className="flex items-center gap-2.5">
                <Skeleton className="h-[9px] w-[70px]" />
                <Skeleton className="size-3.5" />
                <Skeleton className="h-[9px]" style={{ width }} />
              </div>
            ))}
          </div>
          <EmptyState
            className="w-full rounded-[10px] border border-dashed border-input"
            icon={<Folder />}
            title="No projects yet"
            description="Run this in your app’s repo. The project shows up here after the first start."
          />
        </Specimen>

        <Specimen label="Alert with icon · Card">
          <Alert variant="destructive">
            <Camera aria-hidden="true" />
            <div>
              <AlertTitle>Log stream stopped</AlertTitle>
              <AlertDescription>irisrun on localhost:7420 isn’t answering.</AlertDescription>
            </div>
          </Alert>
          <Card className="w-full px-3.5 py-3">
            <div className="text-xs text-muted-foreground">Hosts online</div>
            <div className="text-xl font-semibold">
              3 <span className="text-[13px] font-normal text-muted-foreground">of 5</span>
            </div>
          </Card>
        </Specimen>

        <Specimen label="Menu · Popover · Dialogs">
          <div className="flex flex-wrap gap-2">
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="outline">Host actions</Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="start" className="w-62">
                <DropdownMenuItem>Open a session on this host</DropdownMenuItem>
                <DropdownMenuItem>Restart agent</DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem variant="destructive">Release host…</DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
            <Popover>
              <PopoverTrigger asChild>
                <Button variant="outline">Session details</Button>
              </PopoverTrigger>
              <PopoverContent>
                <div className="font-semibold">Cloud session</div>
                <div className="mt-2 text-[12.5px] text-muted-foreground">sg-m2-01 · Apple M2 · 38 ms</div>
              </PopoverContent>
            </Popover>
            <Dialog>
              <DialogTrigger asChild>
                <Button variant="outline">Dialog</Button>
              </DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Copy your new API key</DialogTitle>
                  <DialogDescription>This is the only time the full key is shown.</DialogDescription>
                </DialogHeader>
                <DialogFooter>
                  <DialogClose asChild>
                    <Button size="lg">Done</Button>
                  </DialogClose>
                </DialogFooter>
              </DialogContent>
            </Dialog>
            <AlertDialog>
              <AlertDialogTrigger asChild>
                <Button variant="outline">Alert dialog</Button>
              </AlertDialogTrigger>
              <AlertDialogContent>
                <AlertDialogHeader>
                  <AlertDialogTitle>Accept the Android SDK license</AlertDialogTitle>
                  <AlertDialogDescription>You’ll only be asked once on this computer.</AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                  <AlertDialogCancel>Decline</AlertDialogCancel>
                  <AlertDialogAction>Accept and continue</AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>
          </div>
        </Specimen>
      </div>
    </section>
  );
}
