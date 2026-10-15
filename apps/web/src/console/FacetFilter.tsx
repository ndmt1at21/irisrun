import { Button } from "../components/ui/button";
import {
  DropdownMenu,
  DropdownMenuCheckboxItem,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "../components/ui/dropdown-menu";

/** A filter chip with a checkbox menu: dashed "+ Actor" when empty, "Actor: A, B ×" when set (AuditLog artboard). */
export function FacetFilter({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: string[];
  value: string[];
  onChange: (value: string[]) => void;
}) {
  return (
    <DropdownMenu>
      {value.length === 0 ? (
        <DropdownMenuTrigger asChild>
          <Button variant="outline" className="border-dashed px-2.5 text-[12.5px] font-normal">
            + {label}
          </Button>
        </DropdownMenuTrigger>
      ) : (
        <span className="inline-flex h-8 items-center rounded-md border border-primary bg-selection text-[12.5px]">
          <DropdownMenuTrigger className="h-full cursor-pointer rounded-md pl-2.5 -outline-offset-2">
            {label}: {value.join(", ")}
          </DropdownMenuTrigger>
          <button
            type="button"
            aria-label={`Clear ${label.toLowerCase()} filter`}
            onClick={() => onChange([])}
            className="h-full cursor-pointer rounded-md pr-2.5 pl-1 -outline-offset-2"
          >
            ×
          </button>
        </span>
      )}
      <DropdownMenuContent align="start">
        {options.map((option) => (
          <DropdownMenuCheckboxItem
            key={option}
            checked={value.includes(option)}
            // Keep options in menu order and the menu open while picking several.
            onCheckedChange={(on) => onChange(options.filter((o) => (o === option ? on : value.includes(o))))}
            onSelect={(event) => event.preventDefault()}
          >
            {option}
          </DropdownMenuCheckboxItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
