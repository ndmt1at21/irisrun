import { Link } from "@tanstack/react-router";
import { Check, Clock, Copy, LoaderCircle, Terminal } from "lucide-react";
import { useState } from "react";
import { Button } from "../../components/ui/button";
import { Card } from "../../components/ui/card";
import { Input } from "../../components/ui/input";
import { Separator } from "../../components/ui/separator";
import { agentToken } from "../../mocks/console/hosts";
import { SectionHeader, Steps } from "./Wizard";

const PENDING = ["Host registered with Acme Mobile", "Xcode and simulator runtimes detected", "Test simulator boots"];

const REQUIREMENTS = [
  "Apple silicon (M1 or newer)",
  "macOS 14 Sonoma or later",
  "Xcode 16 with at least one iOS simulator runtime",
  "Outbound HTTPS (443). No inbound ports.",
  "Stays awake while plugged in",
];

const mono = "font-mono text-foreground";

/** Step 2 of adding a Mac the team runs: the install command, then waiting for the agent to call in. */
export function AnyMacFlow() {
  const [name, setName] = useState("studio-hcm-01");
  const [copied, setCopied] = useState(false);
  const command = `curl -fsSL https://get.irisrun.dev/agent.sh | sh -s -- \\\n    --token ${agentToken.value} \\\n    --name ${name}`;
  const [beforeToken, afterToken] = command.split(agentToken.value);

  function copy() {
    navigator.clipboard?.writeText(command).then(
      () => {
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      },
      () => {},
    );
  }

  return (
    <>
      <Steps
        current={1}
        steps={[
          ["Check requirements", "macOS 14+, Xcode 16"],
          ["Install the agent", "Run one command"],
          ["Host connects", "Detected automatically"],
        ]}
      />

      <div className="flex min-w-0 flex-[999_1_520px] flex-col gap-4">
        <Card>
          <SectionHeader
            title="Run this on the Mac"
            description="Open Terminal on the host and paste the command. It installs the agent as a launch daemon and registers the host with Acme Mobile."
          >
            <span className="inline-flex h-6 items-center gap-1.5 rounded-full border px-2 text-[11.5px] text-muted-foreground">
              <Clock className="size-3" />
              Token expires in <span className={mono}>{agentToken.expiresIn}</span>
            </span>
          </SectionHeader>
          <div className="flex flex-col gap-3.5 px-[18px] py-4">
            <label className="flex max-w-[360px] flex-col gap-1.5 text-[12.5px] font-medium">
              Host name
              <Input value={name} onChange={(event) => setName(event.target.value)} className="font-mono font-normal" />
              <span className="text-xs font-normal text-muted-foreground">
                Shown in Mac hosts and when people pick a cloud simulator.
              </span>
            </label>
            <div className="rounded-lg border bg-code">
              <div className="flex items-center justify-between border-b py-1.5 pr-2 pl-3 text-[11.5px] text-muted-foreground">
                <span className="inline-flex items-center gap-1.5">
                  <Terminal className="size-[13px]" />
                  Terminal · zsh
                </span>
                <Button variant="outline" size="xs" className="h-[26px] bg-background" onClick={copy}>
                  {copied ? <Check className="size-[13px]" /> : <Copy className="size-[13px]" />}
                  {copied ? "Copied" : "Copy command"}
                </Button>
              </div>
              <pre className="overflow-x-auto px-3.5 pt-3.5 pb-4 font-mono text-[12.5px] leading-[1.7]">
                <span className="text-muted-foreground">$ </span>
                {beforeToken}
                <span className="text-link">{agentToken.value}</span>
                {afterToken}
              </pre>
            </div>
            <div className="flex flex-wrap gap-4 text-xs text-muted-foreground">
              <span>Single-use token · works for one host</span>
              <Button variant="link" className="h-auto p-0 text-xs font-normal">
                Generate a new token
              </Button>
              <a href="https://get.irisrun.dev/agent.pkg" target="_blank" rel="noreferrer">
                Install manually (.pkg)
              </a>
            </div>
          </div>
        </Card>

        <Card role="status" aria-live="polite" className="p-[18px]">
          <div className="flex items-center gap-3.5">
            <span
              aria-hidden="true"
              className="relative inline-flex size-9 shrink-0 items-center justify-center rounded-full bg-primary/18"
            >
              <span className="absolute -inset-1.5 rounded-full border border-primary/30" />
              <span className="size-2.5 rounded-full bg-primary" />
            </span>
            <div className="min-w-0 flex-1">
              <div className="font-semibold">Waiting for {name} to connect…</div>
              <div className="text-[12.5px] text-muted-foreground">
                This page updates on its own. You can leave — the host will show up in Mac hosts when it’s ready.
              </div>
            </div>
          </div>
          <ul className="mt-4 flex flex-col gap-2.5 text-[12.5px]">
            <li className="flex items-center gap-2.5">
              <LoaderCircle className="size-4 text-primary motion-safe:animate-spin" strokeWidth={2.4} />
              <span className="font-medium">Listening for the agent</span>
              <span className="text-muted-foreground">· 2 min</span>
            </li>
            {PENDING.map((step) => (
              <li key={step} className="flex items-center gap-2.5 text-muted-foreground">
                <span className="size-4 shrink-0 rounded-full border-[1.5px] border-dashed border-input" />
                {step}
              </li>
            ))}
          </ul>
          <details className="mt-3.5 border-t pt-3 text-[12.5px]">
            <summary className="cursor-pointer text-muted-foreground">Nothing happening after a few minutes?</summary>
            <p className="mt-2 text-muted-foreground">
              The agent only needs outbound HTTPS on port 443. If the Mac is behind a proxy, add{" "}
              <span className={mono}>--proxy http://host:port</span> to the command. Logs:{" "}
              <span className={mono}>/var/log/iris-agent.log</span>
            </p>
          </details>
        </Card>

        <div className="flex flex-wrap items-center gap-2.5">
          <Button variant="outline" className="h-9 px-3.5">
            Back
          </Button>
          <div className="flex-1" />
          <Button asChild variant="ghost" className="h-9 px-3.5 text-muted-foreground hover:text-foreground">
            <Link to="/console/hosts" activeOptions={{ exact: true }}>
              Finish later
            </Link>
          </Button>
          <Button disabled className="h-9 px-4">
            Open a simulator
          </Button>
        </div>
      </div>

      <aside aria-label="Requirements" className="min-w-0 flex-[1_1_274px] rounded-[10px] border bg-card p-4">
        <div className="mb-3 font-semibold">Host requirements</div>
        <ul className="flex flex-col gap-2.5 text-[12.5px]">
          {REQUIREMENTS.map((requirement) => (
            <li key={requirement} className="flex gap-2">
              <Check className="mt-0.5 size-[15px] shrink-0 text-success" strokeWidth={2.4} />
              {requirement}
            </li>
          ))}
        </ul>
        <Separator className="my-3.5" />
        <p className="text-xs text-muted-foreground">
          Simulator video and logs stream from this Mac to your browser. Session data is stored in your organization’s
          data region.
        </p>
      </aside>
    </>
  );
}
