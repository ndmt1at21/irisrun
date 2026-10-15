import { Check, CircleAlert, CircleCheck, ExternalLink, TriangleAlert } from "lucide-react";
import { useState } from "react";
import { Alert, AlertDescription, AlertTitle } from "../../components/ui/alert";
import { Button } from "../../components/ui/button";
import { Card } from "../../components/ui/card";
import { Checkbox } from "../../components/ui/checkbox";
import { Input } from "../../components/ui/input";
import { RadioGroup, RadioGroupItem } from "../../components/ui/radio-group";
import { Separator } from "../../components/ui/separator";
import { cn } from "../../lib/utils";
import { awsAccount, awsRegions, instanceTypes } from "../../mocks/console/hosts";
import { SectionHeader, Steps } from "./Wizard";

const SIMULATORS_PER_HOST = 4;

const stepButton = "cursor-pointer text-base text-muted-foreground focus-visible:-outline-offset-2 disabled:cursor-not-allowed disabled:opacity-50";

/** Step 2 of adding EC2 Mac hosts: region, instance type and count, gated on the 24-hour billing minimum. */
export function AwsFlow({ roleFailed }: { roleFailed: boolean }) {
  const [regionCode, setRegionCode] = useState("ap-southeast-1");
  const [type, setType] = useState("mac2-m2.metal");
  const [count, setCount] = useState(1);
  const [confirmed, setConfirmed] = useState(false);
  const region = awsRegions.find((r) => r.code === regionCode);
  const instance = instanceTypes.find((t) => t.type === type);

  return (
    <>
      <Steps
        current={1}
        steps={[
          ["Connect AWS account", "IAM role verified"],
          ["Region & instance", "Where hosts run"],
          ["Review & provision", "Allocate EC2 Mac"],
        ]}
      />

      <div className="flex min-w-0 flex-[999_1_520px] flex-col gap-4">
        {roleFailed ? (
          <Alert variant="destructive">
            <CircleAlert />
            <div className="min-w-0 flex-1">
              <AlertTitle>Iris can’t use the role {awsAccount.role}</AlertTitle>
              <AlertDescription>
                AWS returned AccessDenied when Iris tried to assume it. The trust policy is probably missing the external
                ID.
              </AlertDescription>
              <code className="mt-2 block truncate rounded-md bg-muted px-2 py-1.5 font-mono text-[11.5px]">
                sts:AssumeRole · ExternalId {awsAccount.externalId}
              </code>
              <div className="mt-2.5 flex flex-wrap gap-2">
                <Button size="xs">Re-run CloudFormation stack</Button>
                <Button size="xs" variant="outline">
                  Check again
                </Button>
              </div>
            </div>
          </Alert>
        ) : (
          <Card className="flex flex-wrap items-center gap-3 px-3.5 py-3">
            <span className="inline-flex size-7 items-center justify-center rounded-full bg-success/14 text-success">
              <Check className="size-[15px]" strokeWidth={2.4} />
            </span>
            <div className="min-w-0 flex-[1_1_260px]">
              <div className="font-medium">AWS account {awsAccount.id} connected</div>
              <div className="truncate font-mono text-[11.5px] text-muted-foreground">{awsAccount.roleArn}</div>
            </div>
            <Button variant="link" className="h-auto p-0 text-xs font-normal">
              Change
            </Button>
          </Card>
        )}

        <Card>
          <SectionHeader
            title="Region"
            description="Pick the region closest to your team. Latency is measured from this browser."
          />
          <RadioGroup aria-label="AWS region" value={regionCode} onValueChange={setRegionCode} className="gap-0 p-2">
            {awsRegions.map((r) => (
              <RadioGroupItem
                key={r.code}
                value={r.code}
                className="group grid grid-cols-[18px_minmax(0,1fr)_auto] items-center gap-3 border-0 bg-transparent p-2.5 data-[state=checked]:border-0"
              >
                <span className="inline-flex size-4 items-center justify-center rounded-full border-[1.5px] border-input group-data-[state=checked]:border-primary">
                  <span className="size-[7px] rounded-full group-data-[state=checked]:bg-primary" />
                </span>
                <span>
                  <span className="font-medium">{r.city}</span>
                  <span className="ml-2 font-mono text-xs text-muted-foreground">{r.code}</span>
                </span>
                <span className="inline-flex items-center gap-1.5 font-mono text-xs text-muted-foreground">
                  <span
                    className={cn(
                      "size-1.5 rounded-full",
                      r.latencyMs < 80 ? "bg-success" : r.latencyMs <= 200 ? "bg-warning" : "bg-destructive",
                    )}
                  />
                  {r.latencyMs} ms
                </span>
              </RadioGroupItem>
            ))}
          </RadioGroup>
        </Card>

        <Card>
          <SectionHeader
            title="Instance type"
            description={`Each host runs up to ${SIMULATORS_PER_HOST} simulators at once.`}
          />
          <RadioGroup
            aria-label="Instance type"
            value={type}
            onValueChange={setType}
            className="grid-cols-[repeat(auto-fit,minmax(170px,1fr))] p-3.5"
          >
            {instanceTypes.map((t) => (
              <RadioGroupItem key={t.type} value={t.type} className="bg-transparent">
                <span className="flex justify-between font-semibold">
                  {t.chip}
                  {t.type === type && <CircleCheck className="size-4 text-link" strokeWidth={2.4} />}
                </span>
                <span className="block font-mono text-[11.5px] text-muted-foreground">{t.type}</span>
                <span className="mt-2 block text-xs text-muted-foreground">{t.specs}</span>
              </RadioGroupItem>
            ))}
          </RadioGroup>
          <div className="flex flex-wrap gap-4 px-3.5 pb-4 text-[12.5px] font-medium">
            <label htmlFor="host-count" className="flex flex-col gap-1.5">
              Hosts
              <span className="inline-flex box-content h-8 items-center overflow-hidden rounded-md border border-input">
                <button
                  type="button"
                  aria-label="Fewer hosts"
                  disabled={count <= 1}
                  onClick={() => setCount(count - 1)}
                  className={cn("size-8", stepButton)}
                >
                  −
                </button>
                <input
                  id="host-count"
                  type="text"
                  inputMode="numeric"
                  maxLength={2}
                  aria-label="Number of hosts"
                  value={count}
                  onChange={(event) => {
                    const next = Number(event.target.value);
                    if (Number.isInteger(next) && next >= 1) setCount(next);
                  }}
                  className="h-8 w-[42px] border-x border-input bg-transparent text-center text-[13px] font-normal focus-visible:-outline-offset-2"
                />
                <button
                  type="button"
                  aria-label="More hosts"
                  disabled={count >= 99}
                  onClick={() => setCount(count + 1)}
                  className={cn("size-8", stepButton)}
                >
                  +
                </button>
              </span>
            </label>
            <label className="flex flex-[1_1_220px] flex-col gap-1.5">
              Host name prefix
              <Input defaultValue="sg-m2" className="font-mono font-normal" />
            </label>
          </div>
        </Card>

        <Alert variant="warning" className="gap-3 rounded-[10px] px-4 py-3.5 [&>svg]:mt-px [&>svg]:size-[18px]">
          <TriangleAlert />
          <div className="min-w-0 flex-1">
            <AlertTitle>EC2 Mac hosts are billed for at least 24 hours</AlertTitle>
            <AlertDescription className="mt-0.5 text-foreground/85">
              AWS allocates a Dedicated Host for every Mac instance, with a 24-hour minimum. Releasing it earlier doesn’t
              reduce the charge. Iris never releases a host on its own inside that window.
            </AlertDescription>
            <label className="mt-2.5 flex items-center gap-2 text-[12.5px] font-medium">
              <Checkbox checked={confirmed} onChange={(event) => setConfirmed(event.target.checked)} />
              I understand {count} {count === 1 ? "host" : "hosts"} will be billed for at least 24 hours
            </label>
          </div>
        </Alert>

        <div className="flex flex-wrap items-center gap-2.5">
          <Button variant="outline" className="h-9 px-3.5">
            Back
          </Button>
          <div className="flex-1" />
          {!confirmed && <span className="text-xs text-muted-foreground">Confirm the 24-hour minimum to continue</span>}
          <Button disabled={!confirmed} className="h-9 px-4">
            Continue to review
          </Button>
        </div>
      </div>

      <aside aria-label="Summary" className="min-w-0 flex-[1_1_274px] rounded-[10px] border bg-card p-4">
        <div className="mb-3 font-semibold">Summary</div>
        <dl className="grid grid-cols-[auto_minmax(0,1fr)] gap-x-3 gap-y-2.5 text-[12.5px] [&>dd]:text-right [&>dt]:text-muted-foreground">
          <dt>Account</dt>
          <dd className="font-mono">{awsAccount.id}</dd>
          <dt>Region</dt>
          <dd>{region?.city}</dd>
          <dt>Instance</dt>
          <dd>
            {count} × {instance?.chip}
          </dd>
          <dt>Simulators</dt>
          <dd>Up to {count * SIMULATORS_PER_HOST} at once</dd>
          <dt>Minimum billing</dt>
          <dd className="font-semibold text-warning">24 hours</dd>
        </dl>
        <Separator className="my-3.5" />
        <p className="text-xs text-muted-foreground">
          AWS bills the host directly to your account. Iris usage is billed separately.
        </p>
        <a
          href="https://aws.amazon.com/ec2/dedicated-hosts/pricing/"
          target="_blank"
          rel="noreferrer"
          className="mt-2 inline-flex items-center gap-1 text-xs"
        >
          EC2 Mac pricing
          <ExternalLink className="size-3" />
        </a>
      </aside>
    </>
  );
}
