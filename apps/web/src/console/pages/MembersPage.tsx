import { Link } from "@tanstack/react-router";
import { Ellipsis, Plus } from "lucide-react";
import { Avatar } from "../../components/ui/avatar";
import { Button } from "../../components/ui/button";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "../../components/ui/dropdown-menu";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../../components/ui/table";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../../components/ui/tabs";
import { cn } from "../../lib/utils";
import { invites, type Member, members, permissions, roles } from "../../mocks/console/members";

const PANEL = "min-w-0 flex-[999_1_562px] overflow-hidden rounded-[10px] border";

export function MembersPage() {
  return (
    <div className="flex w-full max-w-[1200px] flex-col gap-4 p-7">
      <div className="flex flex-wrap items-end gap-3">
        <div className="flex-[1_1_300px]">
          <h1 className="text-[22px] font-semibold tracking-[-0.02em]">Members &amp; roles</h1>
          <p className="mt-1 text-muted-foreground">Who can open sessions, manage hosts and see billing.</p>
        </div>
        <Button size="lg">
          <Plus className="size-[15px]" strokeWidth={2.2} />
          Invite people
        </Button>
      </div>

      <Tabs defaultValue="members" className="flex flex-col gap-4">
        <TabsList aria-label="Members views" variant="underline">
          <TabsTrigger value="members">
            Members <span className="font-normal text-muted-foreground">{members.length}</span>
          </TabsTrigger>
          <TabsTrigger value="invites">
            Pending invites <span className="font-normal text-muted-foreground">{invites.length}</span>
          </TabsTrigger>
        </TabsList>

        <div className="flex flex-wrap items-start gap-4">
          <TabsContent value="members" className={PANEL}>
            {/* The design's 1.6fr 128px 1.3fr 104px 32px, scaled as on the Sessions page. */}
            <Table aria-label="Members" className="min-w-[640px] table-fixed">
              <TableHeader>
                <TableRow className="[&>th]:text-xs">
                  <TableHead className="w-[49%]">Member</TableHead>
                  <TableHead className="w-[140px]">Role</TableHead>
                  <TableHead className="w-[39%]">Projects</TableHead>
                  <TableHead className="w-[116px]">Last active</TableHead>
                  <TableHead className="w-[52px]">
                    <span className="sr-only">Actions</span>
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody className="[&_td]:py-1">
                {members.map((m) => (
                  <TableRow key={m.email} className="h-[53px]">
                    <TableCell>
                      <span className="flex items-center gap-2.5">
                        <Avatar color={m.color} className="size-[30px]">
                          {m.initials}
                        </Avatar>
                        <span className="min-w-0">
                          <span className="block font-medium">{m.name}</span>
                          <span className="block truncate text-xs text-muted-foreground">{m.email}</span>
                        </span>
                      </span>
                    </TableCell>
                    <TableCell>
                      {m.role === "Owner" ? (
                        // The owner's role isn't changed here: a box like the others, without the menu.
                        <span className="inline-flex h-7 items-center rounded-md border border-input px-2 text-[12.5px]">
                          Owner
                        </span>
                      ) : (
                        <Select defaultValue={m.role}>
                          <SelectTrigger aria-label={`Role of ${m.name}`} className="h-7 px-2">
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent>
                            {roles.map((role) => (
                              <SelectItem key={role} value={role}>
                                {role}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      )}
                    </TableCell>
                    <TableCell className="truncate text-[12.5px] text-muted-foreground">{m.projects}</TableCell>
                    <TableCell className={cn("text-[12.5px]", m.lastActive ? "text-muted-foreground" : "text-success")}>
                      {m.lastActive ?? "Active now"}
                    </TableCell>
                    <TableCell>
                      <MemberMenu member={m} />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TabsContent>

          {/* Not in the design: a minimal table in the Members style. */}
          <TabsContent value="invites" className={PANEL}>
            <Table aria-label="Pending invites" className="min-w-[640px] table-fixed">
              <TableHeader>
                <TableRow className="[&>th]:text-xs">
                  <TableHead>Email</TableHead>
                  <TableHead className="w-[112px]">Role</TableHead>
                  <TableHead className="w-[136px]">Invited by</TableHead>
                  <TableHead className="w-[112px]">Sent</TableHead>
                  <TableHead className="w-[156px]">
                    <span className="sr-only">Actions</span>
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody className="text-[12.5px]">
                {invites.map((invite) => (
                  <TableRow key={invite.email} className="h-[53px]">
                    <TableCell className="truncate text-[13px] font-medium">{invite.email}</TableCell>
                    <TableCell>{invite.role}</TableCell>
                    <TableCell>{invite.invitedBy}</TableCell>
                    <TableCell className="text-muted-foreground">{invite.sent}</TableCell>
                    <TableCell className="text-right">
                      <span className="inline-flex gap-1.5">
                        <Button variant="outline" size="xs">
                          Resend
                        </Button>
                        <Button variant="outline" size="xs" className="text-destructive">
                          Revoke
                        </Button>
                      </span>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TabsContent>

          <aside aria-labelledby="roles-title" className="min-w-0 flex-[1_1_334px] rounded-[10px] border p-4">
            <h2 id="roles-title" className="mb-3 text-sm font-semibold">
              What each role can do
            </h2>
            <table aria-label="Role permissions" className="w-full text-[12.5px]">
              <thead>
                <tr className="border-b text-[11.5px] text-muted-foreground">
                  <td />
                  {roles.map((role) => (
                    <th key={role} className="w-12 pb-2 pl-1 text-center font-normal">
                      {role === "Developer" ? "Dev" : role}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {permissions.map(({ action, allowed }) => (
                  <tr key={action} className="border-b">
                    <th scope="row" className="py-2 text-left font-normal">
                      {action}
                    </th>
                    {roles.map((role) => {
                      const yes = allowed.includes(role);
                      return (
                        <td key={role} className={cn("pl-1 text-center", yes ? "text-success" : "text-muted-foreground")}>
                          <span aria-hidden="true">{yes ? "✓" : "—"}</span>
                          <span className="sr-only">{yes ? "Yes" : "No"}</span>
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
            <p className="mt-3 text-xs text-muted-foreground">
              Developers and Viewers only see the projects they’re added to.
            </p>
          </aside>
        </div>
      </Tabs>
    </div>
  );
}

function MemberMenu({ member }: { member: Member }) {
  const owner = member.role === "Owner";
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon-xs" aria-label="Member actions">
          <Ellipsis className="size-[15px]" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem disabled={owner}>Edit projects…</DropdownMenuItem>
        <DropdownMenuItem asChild>
          <Link to="/console/audit-log" className="text-foreground no-underline">
            View in audit log
          </Link>
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem variant="destructive" disabled={owner}>
          Remove member
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
