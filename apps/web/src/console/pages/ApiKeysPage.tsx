import { Check, Copy, Key, Plus } from "lucide-react";
import { useRef, useState } from "react";
import { Button } from "../../components/ui/button";
import { Checkbox } from "../../components/ui/checkbox";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "../../components/ui/dialog";
import { EmptyState } from "../../components/ui/empty-state";
import { Input } from "../../components/ui/input";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../../components/ui/table";
import { useMock } from "../../lib/mock";
import { cn } from "../../lib/utils";
import { apiKeys, newKey } from "../../mocks/console/keys";

export function ApiKeysPage() {
  const mock = useMock();
  const keys = mock === "empty" ? [] : apiKeys;
  // The key form isn't designed yet, so Create key goes straight to the new key.
  const [creating, setCreating] = useState(mock === "new-key");

  return (
    <div className="flex w-full max-w-[1200px] flex-col gap-4 p-7">
      <div className="flex flex-wrap items-end gap-3">
        <div className="flex-[1_1_300px]">
          <h1 className="text-[22px] font-semibold tracking-[-0.02em]">API keys</h1>
          <p className="mt-1 text-muted-foreground">
            For scripts and the irisrun CLI on shared machines. Keys act with the permissions you give them.
          </p>
        </div>
        <Button size="lg" onClick={() => setCreating(true)}>
          <Plus className="size-[15px]" strokeWidth={2.2} />
          Create key
        </Button>
      </div>

      {keys.length === 0 ? (
        <EmptyState
          className="h-[280px] rounded-[10px] border border-dashed border-input"
          icon={<Key />}
          title="No API keys"
          description="Create one to use irisrun from scripts or a shared machine."
          actions={
            <Button size="sm" onClick={() => setCreating(true)}>
              Create key
            </Button>
          }
        />
      ) : (
        <div className="overflow-hidden rounded-[10px] border">
          {/* The design's 1.2fr 150px 1.3fr 1fr 96px 96px 80px, scaled as on the Sessions page. */}
          <Table aria-label="API keys" className="min-w-[860px] table-fixed">
            <TableHeader>
              <TableRow className="[&>th]:text-xs">
                <TableHead className="w-[24.6%]">Name</TableHead>
                <TableHead className="w-[162px]">Key</TableHead>
                <TableHead className="w-[25.6%]">Permissions</TableHead>
                <TableHead className="w-[20%]">Created by</TableHead>
                <TableHead className="w-[108px]">Last used</TableHead>
                <TableHead className="w-[108px]">Expires</TableHead>
                <TableHead className="w-[100px]">
                  <span className="sr-only">Actions</span>
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody className="text-[12.5px]">
              {keys.map((key) => {
                const revoked = key.status === "revoked";
                return (
                  <TableRow key={key.name} className={cn("h-[49px]", revoked && "text-muted-foreground line-through")}>
                    <TableCell className="font-medium">{key.name}</TableCell>
                    <TableCell className="font-mono text-xs text-muted-foreground">{key.prefix}</TableCell>
                    <TableCell className="text-muted-foreground">{key.permissions}</TableCell>
                    <TableCell>{key.createdBy}</TableCell>
                    <TableCell className="text-muted-foreground">{key.lastUsed}</TableCell>
                    <TableCell className={key.status === "expiring" ? "text-warning" : "text-muted-foreground"}>
                      {key.expires}
                    </TableCell>
                    <TableCell className="text-right">
                      <Button
                        variant="outline"
                        size="xs"
                        disabled={revoked}
                        className={revoked ? "text-muted-foreground" : "text-destructive"}
                      >
                        {revoked ? "Revoked" : "Revoke"}
                      </Button>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </div>
      )}

      {creating && <NewKeyDialog onDone={() => setCreating(false)} />}
    </div>
  );
}

/** Shows the new key once; it closes only after the person says they stored it. */
function NewKeyDialog({ onDone }: { onDone: () => void }) {
  const [copied, setCopied] = useState(false);
  const [stored, setStored] = useState(false);
  const input = useRef<HTMLInputElement>(null);
  // Opened from a plain button, not a DialogTrigger, so Radix can't hand focus back on close.
  const [opener] = useState(() => document.activeElement as HTMLElement | null);
  const keepOpen = (event: Event) => {
    if (!stored) event.preventDefault();
  };

  async function copy() {
    try {
      await navigator.clipboard.writeText(newKey.secret);
      setCopied(true);
    } catch {
      // No clipboard access (e.g. plain http): select the key so it can be copied by hand.
      input.current?.select();
    }
  }

  return (
    <Dialog open onOpenChange={onDone}>
      <DialogContent
        onEscapeKeyDown={keepOpen}
        onInteractOutside={keepOpen}
        onOpenAutoFocus={(event) => {
          // Focus the dialog itself, so it reads from the title and the key field shows no focus ring.
          event.preventDefault();
          (event.currentTarget as HTMLElement).focus();
        }}
        onCloseAutoFocus={(event) => {
          event.preventDefault();
          opener?.focus();
        }}
      >
        <DialogHeader>
          <DialogTitle>Copy your new API key</DialogTitle>
          <DialogDescription>
            This is the only time the full key is shown. Store it in your password manager or secrets store before
            closing.
          </DialogDescription>
        </DialogHeader>
        <div className="mx-6 mt-4">
          <label htmlFor="new-api-key" className="mb-1.5 block text-[12.5px] font-medium">
            {newKey.name}
          </label>
          <div className="flex gap-2">
            <Input
              ref={input}
              id="new-api-key"
              aria-label="API key"
              readOnly
              value={newKey.secret}
              className="h-[38px] flex-1 rounded-lg bg-muted px-3 font-mono text-[12.5px]"
            />
            <Button
              variant="outline"
              onClick={copy}
              className={cn(
                "h-[38px] rounded-lg px-3.5",
                copied && "border-success/45 bg-success/10 text-success hover:bg-success/10",
              )}
            >
              {copied ? <Check className="size-3.5" strokeWidth={2.4} /> : <Copy className="size-3.5" />}
              {copied ? "Copied" : "Copy"}
            </Button>
          </div>
        </div>
        <dl className="mx-6 mt-3.5 grid grid-cols-[auto_minmax(0,1fr)] gap-x-4 gap-y-1.5 rounded-lg bg-muted px-3.5 py-3 text-[12.5px]">
          <dt className="text-muted-foreground">Permissions</dt>
          <dd>{newKey.permissions}</dd>
          <dt className="text-muted-foreground">Projects</dt>
          <dd>{newKey.projects}</dd>
          <dt className="text-muted-foreground">Expires</dt>
          <dd>{newKey.expires}</dd>
        </dl>
        <label className="mx-6 mt-4 flex items-center gap-2.5 font-medium">
          <Checkbox checked={stored} onChange={(event) => setStored(event.target.checked)} />
          I’ve stored this key somewhere safe
        </label>
        <DialogFooter>
          <Button size="lg" className="px-4" disabled={!stored} onClick={onDone}>
            Done
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
