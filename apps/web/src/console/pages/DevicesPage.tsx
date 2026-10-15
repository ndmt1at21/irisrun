import { CircleAlert } from "lucide-react";
import { useState } from "react";
import { Alert, AlertDescription, AlertTitle } from "../../components/ui/alert";
import { Tag } from "../../components/ui/badge";
import { Button } from "../../components/ui/button";
import { SearchField } from "../../components/ui/search-field";
import { Segmented, SegmentedItem } from "../../components/ui/segmented";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../../components/ui/table";
import { useMock } from "../../lib/mock";
import { cn } from "../../lib/utils";
import { type Availability, brandCounts, catalogSize, devices } from "../../mocks/console/devices";

const AVAILABILITY: Record<Availability, { label: string; color: string; action: string }> = {
  available: { label: "Available", color: "text-success", action: "Open session" },
  "in-use": { label: "In use", color: "text-warning", action: "Join queue" },
  maintenance: { label: "Maintenance", color: "text-muted-foreground", action: "Unavailable" },
};

const BRANDS = [{ brand: "All", count: catalogSize }, ...brandCounts];
const OSES = [...new Set(devices.map((d) => d.os))];
const COUNTRIES = [...new Set(devices.map((d) => d.country))].sort();
// A filter that is set gets the selected look, as Country has in the design.
const ACTIVE_FILTER = "border-primary bg-selection";

// Location gets 21.3% so Device and Location split 1.6 : 1.1 at full width, as in the design.
const COLUMNS = [
  ["", "w-12"],
  ["Device", ""],
  ["Type", "w-24"],
  ["OS", "w-[108px]"],
  ["Location", "w-[21.3%]"],
  ["Availability", "w-[162px]"],
  ["", "w-[136px]"],
];

export function DevicesPage() {
  const failed = useMock() === "error";
  const [brand, setBrand] = useState("All");
  const [query, setQuery] = useState("");
  const [os, setOs] = useState("any");
  const [country, setCountry] = useState("any");
  const [type, setType] = useState("all");
  const [favorites, setFavorites] = useState(() => Object.fromEntries(devices.map((d) => [d.name, d.favorite])));
  const q = query.trim().toLowerCase();
  const rows = devices.filter(
    (d) =>
      !(failed && d.type === "Real") &&
      (brand === "All" || d.brand === brand) &&
      (os === "any" || d.os === os) &&
      (country === "any" || d.country === country) &&
      (type === "all" || d.type === type) &&
      `${d.name} ${d.maker}`.toLowerCase().includes(q),
  );

  return (
    <div className="flex w-full max-w-[1200px] flex-col gap-4 p-7">
      <div>
        <h1 className="text-[22px] font-semibold tracking-[-0.02em]">Devices</h1>
        <p className="mt-1 text-muted-foreground">
          Virtual devices run on Iris and your Mac hosts. Real devices sit in device labs across Asia.
        </p>
      </div>

      <div role="group" aria-label="Brand" className="flex flex-wrap gap-1.5">
        {BRANDS.map((b) => (
          <Button
            key={b.brand}
            variant="outline"
            size="sm"
            aria-pressed={brand === b.brand}
            onClick={() => setBrand(b.brand)}
            className="rounded-full aria-pressed:border-foreground aria-pressed:bg-foreground aria-pressed:text-background"
          >
            {b.brand}
            <span className="text-[11.5px] opacity-70">{b.count}</span>
          </Button>
        ))}
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <SearchField
          aria-label="Search devices"
          placeholder="Search model"
          className="box-content flex-[0_1_260px]"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
        <Select value={os} onValueChange={setOs}>
          <SelectTrigger aria-label="OS" className={cn(os !== "any" && ACTIVE_FILTER)}>
            <span>
              OS: <SelectValue />
            </span>
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="any">Any</SelectItem>
            {OSES.map((name) => (
              <SelectItem key={name} value={name}>
                {name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Select value={country} onValueChange={setCountry}>
          <SelectTrigger aria-label="Country" className={cn(country !== "any" && ACTIVE_FILTER)}>
            <span>
              Country: <SelectValue />
            </span>
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="any">Any</SelectItem>
            {COUNTRIES.map((name) => (
              <SelectItem key={name} value={name}>
                {name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Segmented aria-label="Device type" value={type} onValueChange={setType}>
          <SegmentedItem value="all">All</SegmentedItem>
          <SegmentedItem value="Virtual">Virtual</SegmentedItem>
          <SegmentedItem value="Real">Real</SegmentedItem>
        </Segmented>
        <span className="flex-1" />
        <span aria-live="polite" className="text-xs text-muted-foreground">
          {rows.length} of {catalogSize} devices
        </span>
      </div>

      {failed && (
        <Alert variant="destructive">
          <CircleAlert aria-hidden="true" />
          <div className="flex-1">
            <AlertTitle>Couldn’t load real devices</AlertTitle>
            <AlertDescription>The Jakarta device lab didn’t answer. Virtual devices are still listed below.</AlertDescription>
            <Button variant="outline" size="xs" className="mt-2.5">
              Try again
            </Button>
          </div>
        </Alert>
      )}

      <div className="overflow-hidden rounded-[10px] border">
        <Table aria-label="Devices" className="min-w-[860px] table-fixed">
          <TableHeader>
            <TableRow>
              {COLUMNS.map(([label, width], i) => (
                <TableHead key={i} className={cn("h-[38px] text-xs", width)}>
                  {label}
                </TableHead>
              ))}
            </TableRow>
          </TableHeader>
          <TableBody className="[&_td]:py-1">
            {rows.map((d) => {
              const favorite = favorites[d.name] === true;
              const status = AVAILABILITY[d.availability];
              return (
                <TableRow key={d.name} className="h-[59px]">
                  <TableCell>
                    <button
                      type="button"
                      aria-label="Favorite"
                      aria-pressed={favorite}
                      onClick={() => setFavorites({ ...favorites, [d.name]: !favorite })}
                      className={cn("size-6 cursor-pointer text-[15px]", favorite ? "text-warning" : "text-muted-foreground")}
                    >
                      {favorite ? "★" : "☆"}
                    </button>
                  </TableCell>
                  <TableCell>
                    <span className="block font-medium">{d.name}</span>
                    <span className="block text-xs text-muted-foreground">{d.maker}</span>
                  </TableCell>
                  <TableCell>
                    <Tag className="text-[11.5px]">{d.type}</Tag>
                  </TableCell>
                  <TableCell className="text-[12.5px]">{d.os}</TableCell>
                  <TableCell className="text-[12.5px]">
                    {d.country}
                    {d.city && ` · ${d.city}`}
                  </TableCell>
                  <TableCell>
                    <span className={cn("inline-flex items-center gap-1.5 text-[12.5px]", status.color)}>
                      <span aria-hidden="true" className="size-[7px] rounded-full bg-current" />
                      {status.label}
                      {d.waiting ? ` · ${d.waiting} waiting` : null}
                    </span>
                  </TableCell>
                  <TableCell className="text-right">
                    <Button
                      size="sm"
                      variant={d.availability === "available" ? "default" : "outline"}
                      disabled={d.availability === "maintenance"}
                      className="text-xs"
                    >
                      {status.action}
                    </Button>
                  </TableCell>
                </TableRow>
              );
            })}
          </TableBody>
        </Table>
      </div>
    </div>
  );
}
