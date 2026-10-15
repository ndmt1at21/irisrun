import { Check } from "lucide-react";
import type { ReactNode } from "react";
import { cn } from "../../lib/utils";

/** The wizard's step list: steps before `current` are done, the rest are next. */
export function Steps({ steps, current }: { steps: [title: string, detail: string][]; current: number }) {
  return (
    <ol aria-label="Steps" className="flex flex-[0_1_200px] flex-col gap-1">
      {steps.map(([title, detail], index) => (
        <li
          key={title}
          aria-current={index === current ? "step" : undefined}
          className={cn("flex gap-2.5 py-1.5", index > current && "text-muted-foreground")}
        >
          <span
            className={cn(
              "inline-flex size-[22px] shrink-0 items-center justify-center rounded-full text-[11px] font-semibold",
              index < current && "bg-primary text-primary-foreground",
              index === current && "border-2 border-primary text-link",
              index > current && "border border-input",
            )}
          >
            {index < current ? <Check className="size-3" strokeWidth={3} /> : index + 1}
          </span>
          <span>
            <span className={cn("block", index === current ? "font-semibold" : "font-medium")}>{title}</span>
            <span className={cn("block text-xs", index <= current && "text-muted-foreground")}>{detail}</span>
          </span>
        </li>
      ))}
    </ol>
  );
}

/** The heading row of a wizard card; children sit at its right. */
export function SectionHeader({ title, description, children }: { title: string; description: string; children?: ReactNode }) {
  return (
    <div className="flex flex-wrap items-start gap-3 border-b px-[18px] py-4">
      <div className="flex-[1_1_260px]">
        <h2 className="text-[15px] font-semibold">{title}</h2>
        <p className="mt-0.5 text-[12.5px] text-muted-foreground">{description}</p>
      </div>
      {children}
    </div>
  );
}
