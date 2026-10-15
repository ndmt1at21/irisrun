import { useRouter } from "@tanstack/react-router";
import { IrisLogo } from "../components/IrisLogo";
import { ThemeToggle } from "../components/ThemeToggle";
import { TopBar } from "../components/TopBar";
import { Separator } from "../components/ui/separator";
import { consoleEntries, deviceEntries, foundationEntries } from "./entries";

const GROUPS = [
  { title: "Device UI", entries: deviceEntries },
  { title: "Console", entries: consoleEntries },
  { title: "Foundations", entries: foundationEntries },
];

/** Route `/screens`: every screen and state, for review against the design. */
export function GalleryPage() {
  const { history } = useRouter();
  return (
    <div className="min-h-screen bg-background">
      <TopBar>
        <IrisLogo />
        <span className="text-sm font-semibold tracking-[-0.01em]">Iris</span>
        <Separator orientation="vertical" />
        <h1 className="font-medium">Screens</h1>
        <span className="flex-1" />
        <ThemeToggle />
      </TopBar>
      <div className="mx-auto flex max-w-[1200px] flex-col gap-8 px-4 py-7 sm:px-7">
        {GROUPS.map(({ title, entries }) => (
          <section key={title} aria-label={title}>
            <h2 className="mb-3 text-base font-semibold">
              {title} <span className="font-normal text-muted-foreground">{entries.length}</span>
            </h2>
            <ul className="grid grid-cols-[repeat(auto-fill,minmax(min(260px,100%),1fr))] gap-2.5">
              {entries.map((entry) => (
                <li key={entry.href}>
                  <a
                    href={history.createHref(entry.href)}
                    className="flex h-full flex-col gap-0.5 rounded-[10px] border px-3.5 py-3 text-foreground no-underline hover:bg-accent hover:text-foreground"
                  >
                    <span className="font-medium">{entry.title}</span>
                    <span className="truncate font-mono text-[11.5px] text-muted-foreground">{entry.href}</span>
                    <span className="text-xs text-muted-foreground">{entry.artboard}</span>
                  </a>
                </li>
              ))}
            </ul>
          </section>
        ))}
      </div>
    </div>
  );
}
