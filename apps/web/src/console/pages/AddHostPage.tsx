import { Link } from "@tanstack/react-router";
import { ChevronRight } from "lucide-react";
import { useState } from "react";
import { Tag } from "../../components/ui/badge";
import { Button } from "../../components/ui/button";
import { RadioGroup, RadioGroupItem } from "../../components/ui/radio-group";
import { useMock } from "../../lib/mock";
import { AnyMacFlow } from "../hosts/AnyMacFlow";
import { AwsFlow } from "../hosts/AwsFlow";

const METHODS = [
  {
    value: "aws",
    title: "Connect AWS",
    tag: "Managed by Iris",
    description: "Iris creates an IAM role, allocates EC2 Mac hosts in your account and keeps them patched.",
  },
  {
    value: "any-mac",
    title: "Any Mac",
    description: "Install a small agent on a Mac mini, Mac Studio or MacBook you already run.",
  },
];

export function AddHostPage() {
  const mock = useMock();
  const [method, setMethod] = useState(mock === "any-mac" ? "any-mac" : "aws");

  return (
    <>
      <div className="flex min-h-[52px] flex-wrap items-center gap-3 border-b px-7">
        <nav aria-label="Breadcrumb" className="flex items-center gap-2 text-muted-foreground">
          <Link to="/console/hosts" activeOptions={{ exact: true }} className="text-muted-foreground hover:text-foreground">
            Mac hosts
          </Link>
          <ChevronRight className="size-3.5" />
          <span className="font-medium text-foreground">Add host</span>
        </nav>
        <div className="flex-1" />
        <a
          href="https://irisrun.dev/docs/mac-hosts"
          target="_blank"
          rel="noreferrer"
          className="text-xs text-muted-foreground hover:text-foreground"
        >
          Docs
        </a>
        <Button asChild variant="outline">
          <Link to="/console/hosts" activeOptions={{ exact: true }}>
            Cancel
          </Link>
        </Button>
      </div>

      <div className="flex w-full max-w-[1180px] flex-col gap-[22px] p-7">
        <div>
          <h1 className="text-[22px] font-semibold tracking-[-0.02em]">Add a Mac host</h1>
          <p className="mt-1 max-w-[680px] text-muted-foreground">
            Mac hosts run the cloud iOS simulators your team opens from Iris. Let Iris provision EC2 Mac hosts in your AWS
            account, or connect any Mac you manage.
          </p>
        </div>

        <RadioGroup
          aria-label="How to add the host"
          value={method}
          onValueChange={setMethod}
          className="grid-cols-[repeat(auto-fit,minmax(260px,1fr))] gap-3"
        >
          {METHODS.map(({ value, title, tag, description }) => (
            <RadioGroupItem key={value} value={value} className="group flex gap-3 rounded-[10px] px-4 py-3.5">
              <span className="mt-px inline-flex size-[18px] shrink-0 items-center justify-center rounded-full border-[1.5px] border-input group-data-[state=checked]:border-primary">
                <span className="size-2 rounded-full group-data-[state=checked]:bg-primary" />
              </span>
              <span>
                <span className="flex items-center gap-2 font-semibold">
                  {title}
                  {tag && <Tag className="bg-background font-medium">{tag}</Tag>}
                </span>
                <span className="mt-0.5 block text-[12.5px] text-muted-foreground">{description}</span>
              </span>
            </RadioGroupItem>
          ))}
        </RadioGroup>

        <div className="flex flex-wrap items-start gap-7">
          {method === "aws" ? <AwsFlow roleFailed={mock === "aws-role-failed"} /> : <AnyMacFlow />}
        </div>
      </div>
    </>
  );
}
