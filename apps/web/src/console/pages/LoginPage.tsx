import { Link } from "@tanstack/react-router";
import { Check, Clock } from "lucide-react";
import { IrisLogo } from "../../components/IrisLogo";
import { Button } from "../../components/ui/button";
import { EmptyState } from "../../components/ui/empty-state";
import { Input } from "../../components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../components/ui/select";
import { useMock } from "../../lib/mock";

// Docs, SSO and the legal pages don't exist yet; their links stay on this page,
// like the design's `#docs` anchors (a bare `#docs` would be a route under hash history).

export function LoginPage() {
  const expired = useMock() === "link-expired";
  return (
    <div className="flex min-h-screen flex-wrap bg-background leading-normal">
      <main className="flex min-w-0 flex-[1_1_520px] flex-col p-8">
        <div className="flex items-center gap-2">
          <IrisLogo size={22} />
          <span className="text-base font-semibold">Iris</span>
          <span className="ml-1 text-xs text-muted-foreground">Console</span>
        </div>
        <div className="flex flex-1 items-center justify-center py-10">
          {expired ? (
            <EmptyState
              tone="warning"
              icon={<Clock />}
              title={<h1>This sign-in link has expired</h1>}
              description="Links work for 15 minutes. We can send a fresh one to minh@acme.example."
              actions={<Button size="sm">Send a new link</Button>}
            />
          ) : (
            <form className="flex w-full max-w-[360px] flex-col gap-3" onSubmit={(event) => event.preventDefault()}>
              <h1 className="text-2xl font-semibold tracking-[-0.02em]">Sign in to Iris</h1>
              <p className="mb-2 text-muted-foreground">Manage cloud devices, Mac hosts and your team.</p>
              <Button variant="outline" size="xl" className="gap-2.5">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <path d="M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 1.5-2.64-.5-5.36-.5-8 0C6 2 5 2 5 2c-.3 1.15-.3 2.35 0 3.5A5.403 5.403 0 0 0 4 9c0 3.5 3 5.5 6 5.5-.39.49-.68 1.05-.85 1.65-.17.6-.22 1.23-.15 1.85v4" />
                  <path d="M9 18c-4.51 2-5-2-7-2" />
                </svg>
                Continue with GitHub
              </Button>
              <Button variant="outline" size="xl" className="gap-2.5">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <circle cx="12" cy="12" r="10" />
                  <path d="M12 12h8" />
                </svg>
                Continue with Google
              </Button>
              <div role="separator" className="my-1.5 flex items-center gap-2.5 text-xs text-muted-foreground">
                <span className="h-px flex-1 bg-border" />
                or
                <span className="h-px flex-1 bg-border" />
              </div>
              <label className="flex flex-col gap-1.5 text-[12.5px] font-medium">
                Work email
                <Input type="email" placeholder="you@company.com" className="h-[38px] rounded-lg px-3 text-[12.5px] font-normal" />
              </label>
              <Button size="xl">Continue with email</Button>
              <Link to="." search hash="sso" className="self-center text-[12.5px] no-underline">
                Use single sign-on (SAML)
              </Link>
              <p className="mt-3 text-center text-xs text-muted-foreground">
                New to Iris? Signing in creates your account. By continuing you agree to the{" "}
                <Link to="." search hash="terms" className="text-muted-foreground underline">
                  Terms
                </Link>{" "}
                and{" "}
                <Link to="." search hash="privacy" className="text-muted-foreground underline">
                  Privacy Policy
                </Link>
                .
              </p>
            </form>
          )}
        </div>
        <div className="flex flex-wrap gap-4 text-xs text-muted-foreground">
          <span>Status: all systems normal</span>
          <Link to="." search hash="docs" className="text-muted-foreground no-underline">
            Docs
          </Link>
          <span className="flex-1" />
          <Select defaultValue="en">
            <SelectTrigger aria-label="Language" className="h-7 px-2 text-xs">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="en">English</SelectItem>
              <SelectItem value="vi">Tiếng Việt</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </main>

      <aside aria-label="About Iris" className="flex min-w-0 flex-[1_1_520px] items-center justify-center border-l bg-side p-8">
        <div className="flex w-full max-w-[520px] flex-col gap-5">
          <p className="text-xl leading-[1.35] font-semibold tracking-[-0.02em]">
            Run Android and iOS apps from source, right in the browser.
          </p>
          <div className="overflow-hidden rounded-xl border border-[#27272a] bg-[#0b0b0e] shadow-[0_24px_48px_-24px_rgba(0,0,0,.5)]">
            <div className="flex gap-1.5 border-b border-[#27272a] px-3 py-2.5">
              <span className="size-2.5 rounded-full bg-[#3f3f46]" />
              <span className="size-2.5 rounded-full bg-[#3f3f46]" />
              <span className="size-2.5 rounded-full bg-[#3f3f46]" />
            </div>
            <pre className="overflow-x-auto p-4 font-mono text-[12.5px] leading-[1.8] text-[#e4e4e7]">
              <span className="text-[#71717a]">~/code/kedai-android $</span> irisrun start{"\n"}
              <span className="text-[#4ade80]">✓</span> Toolchain ready <span className="text-[#71717a]">(cached)</span>
              {"\n"}
              <span className="text-[#4ade80]">✓</span> Built app:debug in 18.4 s{"\n"}
              <span className="text-[#4ade80]">✓</span> Pixel 8 · Android 14 booted{"\n"}
              <span className="text-[#b1a9ff]">→</span> Open http://localhost:7420
            </pre>
          </div>
          <ul className="flex flex-col gap-2.5 text-muted-foreground">
            {[
              "No phone, Xcode or Android Studio needed",
              "Cloud devices from Samsung, Xiaomi, OPPO, vivo, realme and iPhone",
              "Data stays in the region your team picks",
            ].map((point) => (
              <li key={point} className="flex gap-2.5">
                <Check aria-hidden="true" className="mt-0.5 size-4 shrink-0 text-success" strokeWidth={2.4} />
                {point}
              </li>
            ))}
          </ul>
        </div>
      </aside>
    </div>
  );
}
