import { Link } from "@tanstack/react-router";
import {
  Bell,
  Camera,
  CreditCard,
  Database,
  ImageIcon,
  LinkIcon,
  type LucideIcon,
  MapPin,
  ScanFace,
  UserRound,
} from "lucide-react";
import { type ChangeEvent, type ReactNode, useEffect, useId, useRef, useState } from "react";
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
} from "../../components/ui/alert-dialog";
import { Button, buttonVariants } from "../../components/ui/button";
import { Checkbox } from "../../components/ui/checkbox";
import { Input } from "../../components/ui/input";
import { Segmented, SegmentedItem } from "../../components/ui/segmented";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../components/ui/select";
import { Switch } from "../../components/ui/switch";
import { Textarea } from "../../components/ui/textarea";
import { cn } from "../../lib/utils";
import { kedaiAdapters, type PaymentResult, paymentResults } from "../../mocks/device/adapters";

const PICKED: Record<PaymentResult, string> = {
  success: "border-success/50 text-success",
  declined: "border-destructive/50 text-destructive",
  pending: "border-warning/50 text-warning",
  cancelled: "border-foreground/50",
};
const SOURCES = [
  ["webcam", "Webcam"],
  ["image", "Image file"],
] as const;
const LABEL = "flex flex-col gap-1 text-[11.5px] text-muted-foreground";
const FIELD = "h-[30px] px-2";
const SMALL = "h-[30px] px-2.5 text-xs font-normal";
// The placeholder map's corners around the start location in Ho Chi Minh City, in degrees.
const MAP = { north: 10.7905, west: 106.6818, height: 0.03, width: 0.04 };

function Section({
  icon: Icon,
  title,
  aside,
  children,
}: {
  icon: LucideIcon;
  title: string;
  /** Right-aligned in the header. */
  aside?: ReactNode;
  children: ReactNode;
}) {
  const id = useId();
  return (
    <section aria-labelledby={id} className="rounded-[10px] border bg-card p-3.5">
      <div className="mb-2.5 flex items-center gap-2">
        <Icon className="size-4" />
        <h3 id={id} className="text-[13.5px] font-semibold">
          {title}
        </h3>
        <span className="flex-1" />
        {aside}
      </div>
      {children}
    </section>
  );
}

function Preview({ icon: Icon, children }: { icon: LucideIcon; children: ReactNode }) {
  return (
    <div className="flex h-[132px] flex-col items-center justify-center gap-1.5 rounded-lg bg-[#18181b] text-xs text-[#a1a1aa]">
      <Icon className="size-7" strokeWidth={1.6} />
      {children}
    </div>
  );
}

/** Webcam or an image file as the device's camera; `blocked` when the browser denied the webcam. */
function CameraAdapter({ blocked }: { blocked: boolean }) {
  const [source, setSource] = useState("webcam");
  const [image, setImage] = useState<string>();
  const file = useRef<HTMLInputElement>(null);
  useEffect(
    () => () => {
      if (image) URL.revokeObjectURL(image);
    },
    [image],
  );

  const pick = (event: ChangeEvent<HTMLInputElement>) => {
    const chosen = event.target.files?.[0];
    if (!chosen?.type.startsWith("image/")) return;
    setImage(URL.createObjectURL(chosen));
    setSource("image");
  };
  const chooseImage = (
    <>
      <Button variant="outline" className={cn(SMALL, blocked && "h-7")} onClick={() => file.current?.click()}>
        Choose image…
      </Button>
      <input ref={file} type="file" accept="image/*" hidden onChange={pick} />
    </>
  );

  return (
    <Section
      icon={Camera}
      title="Camera"
      aside={
        !blocked && (
          <Segmented aria-label="Camera source" value={source} onValueChange={setSource} className="gap-0 rounded-md p-0.5">
            {SOURCES.map(([value, label]) => (
              <SegmentedItem
                key={value}
                value={value}
                className="h-[22px] rounded-sm px-2 text-[11.5px] font-normal data-[state=on]:shadow-none"
              >
                {label}
              </SegmentedItem>
            ))}
          </Segmented>
        )
      }
    >
      {source === "image" && image ? (
        <img src={image} alt="Chosen camera image" className="h-[132px] w-full rounded-lg bg-[#18181b] object-contain" />
      ) : source === "image" ? (
        <Preview icon={ImageIcon}>No image chosen</Preview>
      ) : blocked ? (
        <div className="box-content flex h-28 flex-col items-center justify-center gap-1 rounded-lg border border-dashed border-input px-4 text-center">
          <span className="font-medium">Camera access is blocked</span>
          <span className="text-xs text-muted-foreground">
            Allow it from the lock icon in the address bar, or use an image file instead.
          </span>
        </div>
      ) : (
        <Preview icon={UserRound}>Live webcam preview</Preview>
      )}
      <div className="mt-2.5 flex gap-2">
        {blocked ? (
          <Button className="h-7 px-2.5 text-xs">Ask again</Button>
        ) : (
          <Select defaultValue={kedaiAdapters.cameras[0]}>
            <SelectTrigger aria-label="Camera" className="h-[30px] min-w-0 flex-1 text-xs">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {kedaiAdapters.cameras.map((camera) => (
                <SelectItem key={camera} value={camera}>
                  {camera}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        )}
        {chooseImage}
      </div>
    </Section>
  );
}

/** A placeholder map: a click drops the pin and sets the coordinates, which can also be typed. */
function LocationAdapter() {
  const [latitude, setLatitude] = useState(kedaiAdapters.location.latitude);
  const [longitude, setLongitude] = useState(kedaiAdapters.location.longitude);
  // Off the map (or not a number) hides the pin.
  const x = ((Number(longitude) - MAP.west) / MAP.width) * 100;
  const y = ((MAP.north - Number(latitude)) / MAP.height) * 100;
  const geolocation = "geolocation" in navigator;

  return (
    <Section icon={MapPin} title="Location">
      <div
        aria-label="Map — click to set location"
        onClick={(event) => {
          const box = event.currentTarget.getBoundingClientRect();
          setLatitude((MAP.north - ((event.clientY - box.top) / box.height) * MAP.height).toFixed(4));
          setLongitude((MAP.west + ((event.clientX - box.left) / box.width) * MAP.width).toFixed(4));
        }}
        className="relative box-content h-[92px] cursor-crosshair rounded-lg border bg-muted bg-[linear-gradient(var(--border)_1px,transparent_1px),linear-gradient(90deg,var(--border)_1px,transparent_1px)] bg-[size:22px_22px]"
      >
        {x >= 0 && x <= 100 && y >= 0 && y <= 100 && (
          <svg
            aria-hidden="true"
            viewBox="0 0 24 24"
            fill="currentColor"
            stroke="#ffffff"
            strokeWidth="1.5"
            style={{ left: `${x}%`, top: `${y}%` }}
            className="pointer-events-none absolute size-[22px] -translate-x-1/2 -translate-y-full text-primary"
          >
            <path d="M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0" />
          </svg>
        )}
        <span className="absolute bottom-1.5 left-2 text-[11px] text-muted-foreground">Click the map to drop a pin</span>
      </div>
      <div className="mt-2.5 grid grid-cols-2 gap-2">
        <label className={LABEL}>
          Latitude
          <Input
            inputMode="decimal"
            value={latitude}
            onChange={(event) => setLatitude(event.target.value)}
            className={cn(FIELD, "font-mono text-xs")}
          />
        </label>
        <label className={LABEL}>
          Longitude
          <Input
            inputMode="decimal"
            value={longitude}
            onChange={(event) => setLongitude(event.target.value)}
            className={cn(FIELD, "font-mono text-xs")}
          />
        </label>
      </div>
      <Button
        variant="outline"
        disabled={!geolocation}
        className={cn(SMALL, "mt-2 w-full")}
        onClick={() =>
          navigator.geolocation.getCurrentPosition(({ coords }) => {
            setLatitude(coords.latitude.toFixed(4));
            setLongitude(coords.longitude.toFixed(4));
          })
        }
      >
        Use my browser’s location
      </Button>
    </Section>
  );
}

function BiometricsAdapter() {
  const [enrolled, setEnrolled] = useState(true);
  return (
    <Section
      icon={ScanFace}
      title="Biometrics"
      aside={
        <label className="inline-flex items-center gap-1.5 text-xs text-muted-foreground">
          <Switch aria-label="Face ID enrolled" checked={enrolled} onCheckedChange={setEnrolled} />
          Face ID enrolled
        </label>
      }
    >
      <p className="mb-2.5 text-xs text-muted-foreground">Answer the next Face ID prompt from the app.</p>
      <div className="grid grid-cols-2 gap-2">
        <Button variant="outline" size="lg" disabled={!enrolled}>
          Match
        </Button>
        <Button variant="outline" size="lg" disabled={!enrolled}>
          No match
        </Button>
      </div>
    </Section>
  );
}

function StorageAdapter() {
  const { total, areas } = kedaiAdapters.storage;
  return (
    <Section icon={Database} title="Storage" aside={<span className="text-xs text-muted-foreground">{total}</span>}>
      <ul className="-mt-0.5 text-[12.5px]">
        {areas.map(({ name, detail, action }) => (
          <li key={name} className="flex items-center gap-2 border-b py-1.5 last:border-b-0">
            <span className="flex-1">{name}</span>
            <span className="text-muted-foreground">{detail}</span>
            {action === "view" ? (
              <Link to="." search hash={`storage-${name.toLowerCase()}`} className="no-underline">
                View
              </Link>
            ) : (
              <Button variant="link" className="h-auto p-0 text-[12.5px] font-normal hover:no-underline">
                Clear
              </Button>
            )}
          </li>
        ))}
      </ul>
      <AlertDialog>
        <AlertDialogTrigger asChild>
          <Button variant="destructive" className="mt-2 h-[30px] w-full text-xs">
            Erase all app data…
          </Button>
        </AlertDialogTrigger>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Erase all app data?</AlertDialogTitle>
            <AlertDialogDescription>
              UserDefaults, the Keychain, Documents and Caches ({total}) are deleted, as if the app were just installed.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction className={buttonVariants({ variant: "destructive", size: "lg" })}>Erase all data</AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </Section>
  );
}

function DeepLinkAdapter() {
  const [link, setLink] = useState(kedaiAdapters.deepLink);
  return (
    <Section icon={LinkIcon} title="Deep link">
      <div className="flex gap-2">
        <label className="min-w-0 flex-1">
          <span className="sr-only">URL</span>
          <Input type="url" value={link} onChange={(event) => setLink(event.target.value)} className={cn(FIELD, "font-mono text-xs")} />
        </label>
        <Button size="sm" className="px-3.5 text-xs">
          Open
        </Button>
      </div>
      <div className="mt-2.5 text-[11.5px] text-muted-foreground">Recent</div>
      <ul className="mt-1">
        {kedaiAdapters.recentLinks.map((recent) => (
          <li key={recent} className="flex py-1">
            <Button
              variant="link"
              className="h-auto p-0 font-mono text-xs font-normal hover:no-underline"
              onClick={() => setLink(recent)}
            >
              {recent}
            </Button>
          </li>
        ))}
      </ul>
    </Section>
  );
}

/**
 * The Adapters panel: answers the app's payment, camera, location, push, biometrics, storage and deep link
 * requests. The payment result is shared with the sheet on the phone through `result` and `onResult`.
 * `state` is a PanelStates state: `camera-blocked`; none means every adapter works.
 */
export function AdaptersPanel({
  state,
  result,
  onResult,
}: {
  state?: string;
  result?: PaymentResult;
  onResult?: (result: PaymentResult) => void;
}) {
  const [own, setOwn] = useState<PaymentResult>("success");
  const chosen = result ?? own;
  const choose = onResult ?? setOwn;
  const paymentId = useId();
  const { payment, push } = kedaiAdapters;

  // `relative` makes the scroller contain its absolutely positioned bits (sr-only labels, Radix's hidden
  // select); otherwise they stretch the page.
  return (
    <div className="relative grid min-h-0 flex-1 grid-cols-[repeat(auto-fill,minmax(340px,1fr))] content-start gap-3 overflow-auto p-3.5">
      <section aria-labelledby={paymentId} className="col-span-full rounded-[10px] border-[1.5px] border-primary bg-selection p-3.5">
        <div className="flex flex-wrap items-center gap-2">
          <CreditCard className="size-4" />
          <h3 id={paymentId} className="text-[13.5px] font-semibold">
            Payment
          </h3>
          <span className="inline-flex h-5 items-center rounded-full bg-primary px-[7px] text-[11px] font-medium text-primary-foreground">
            Waiting for your choice
          </span>
          <span className="flex-1" />
          <span className="font-mono text-[11.5px] text-muted-foreground">
            {payment.api} · {payment.amount} · {payment.source}
          </span>
        </div>
        <div className="mt-3 grid grid-cols-[repeat(auto-fit,minmax(110px,1fr))] gap-2">
          {paymentResults.map(({ value, label }) => (
            <Button
              key={value}
              variant="outline"
              size="lg"
              aria-pressed={value === chosen}
              onClick={() => choose(value)}
              className={cn("bg-background", value === chosen && PICKED[value])}
            >
              {label}
            </Button>
          ))}
        </div>
        <label className="mt-2.5 inline-flex items-center gap-2 text-xs text-muted-foreground">
          <Checkbox className="size-[13px]" />
          Answer future payments with the same result automatically
        </label>
      </section>
      <CameraAdapter blocked={state === "camera-blocked"} />
      <LocationAdapter />
      <Section icon={Bell} title="Push notification">
        <div className="flex flex-col gap-2">
          <label className={LABEL}>
            Title
            <Input defaultValue={push.title} className={cn(FIELD, "text-[12.5px]")} />
          </label>
          <label className={LABEL}>
            Body
            <Input defaultValue={push.body} className={cn(FIELD, "text-[12.5px]")} />
          </label>
          <label className={LABEL}>
            Payload (JSON)
            <Textarea rows={3} defaultValue={push.payload} className="min-h-0 bg-code px-2 font-mono text-[11.5px] leading-[1.3]" />
          </label>
          <Button size="sm" className="self-end px-3.5 text-xs">
            Send
          </Button>
        </div>
      </Section>
      <BiometricsAdapter />
      <StorageAdapter />
      <DeepLinkAdapter />
    </div>
  );
}
