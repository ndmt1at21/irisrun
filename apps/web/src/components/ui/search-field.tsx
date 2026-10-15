import { Search } from "lucide-react";
import type { ComponentProps } from "react";
import { cn } from "../../lib/utils";

/** A search input with a magnifier; `className` styles the box, the rest goes to the input. */
function SearchField({ className, ...props }: Omit<ComponentProps<"input">, "type">) {
  return (
    <label
      data-slot="search-field"
      className={cn(
        "flex h-8 min-w-0 items-center gap-2 rounded-md border border-input px-2.5 text-[12.5px] text-muted-foreground focus-within:border-ring focus-within:ring-[3px] focus-within:ring-ring/18",
        className,
      )}
    >
      <Search aria-hidden="true" className="size-3.5 shrink-0" />
      <input
        type="search"
        className="h-full min-w-0 flex-1 bg-transparent px-0.5 text-foreground outline-none placeholder:text-muted-foreground"
        {...props}
      />
    </label>
  );
}

export { SearchField };
