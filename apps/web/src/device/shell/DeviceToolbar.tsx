import { ALargeSmall, Languages, type LucideIcon, Moon, RotateCw, Smartphone } from "lucide-react";
import { useState } from "react";
import { Button } from "../../components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../../components/ui/select";
import { Separator } from "../../components/ui/separator";
import type { Platform } from "./frames";

/** What the bar above the device shows, e.g. Pixel 8 · Android 14 · API 34 · Tiếng Việt · Font 100%. */
export interface DeviceToolbarInfo {
  device: string;
  os: string;
  language: string;
  textSize: string;
  /** Mono text at the right, e.g. "1080 × 2400 · 420 dpi · 72%". */
  resolution?: string;
  /** Muted text at the right, e.g. "Continued from local · state reset". */
  note?: string;
}

// Mock choices; the current value always comes first.
const DEVICES: Record<Platform, { name: string; os: string }[]> = {
  android: [
    { name: "Pixel 8", os: "Android 14 · API 34" },
    { name: "Pixel 7a", os: "Android 13 · API 33" },
    { name: "Galaxy A55", os: "Android 14 · API 34" },
    { name: "Pixel Tablet", os: "Android 14 · API 34" },
  ],
  ios: [
    { name: "iPhone 15 Pro", os: "iOS 18.0" },
    { name: "iPhone 15", os: "iOS 18.0" },
    { name: "iPhone SE (3rd generation)", os: "iOS 17.5" },
    { name: "iPad Air 11-inch", os: "iOS 18.0" },
  ],
};
const LANGUAGES = ["English · en-US", "Tiếng Việt · vi-VN", "Bahasa Indonesia · id-ID", "ไทย · th-TH", "日本語 · ja-JP"];
const TEXT_SIZES: Record<Platform, string[]> = {
  android: ["Font 85%", "Font 100%", "Font 115%", "Font 130%"],
  ios: ["Text size · Small", "Text size · Default", "Text size · Large", "Text size · Extra Large"],
};

const first = (value: string, options: string[]) => [value, ...options.filter((option) => option !== value)];

export function DeviceToolbar({ platform, ...info }: DeviceToolbarInfo & { platform: Platform }) {
  const [dark, setDark] = useState(false);
  const devices = [{ name: info.device, os: info.os }, ...DEVICES[platform].filter(({ name }) => name !== info.device)];
  return (
    <div className="flex flex-wrap items-center gap-1.5 border-b bg-background px-3 py-2">
      <Select defaultValue={info.device}>
        <SelectTrigger aria-label="Device" className="h-[30px] gap-2 bg-background pr-2 pl-2.5 text-xs [&>svg:last-child]:size-3.5">
          <Smartphone className="size-3.5" />
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {devices.map(({ name, os }) => (
            <SelectItem key={name} value={name}>
              <span className="flex gap-2">
                <span className="font-medium">{name}</span>
                <span className="text-muted-foreground">{os}</span>
              </span>
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      <Separator orientation="vertical" className="mx-0.5 h-[18px]" />
      <Button variant="ghost" size="icon-sm" aria-label="Rotate device" title="Rotate">
        <RotateCw />
      </Button>
      <Button
        variant="ghost"
        size="icon-sm"
        aria-label="Device dark mode"
        aria-pressed={dark}
        title="Dark mode"
        onClick={() => setDark(!dark)}
      >
        <Moon />
      </Button>
      <Choice label="Device language" icon={Languages} value={info.language} options={first(info.language, LANGUAGES)} />
      <Choice
        label={platform === "ios" ? "Text size" : "Font size"}
        icon={ALargeSmall}
        value={info.textSize}
        options={first(info.textSize, TEXT_SIZES[platform])}
      />
      <span className="flex-1" />
      {info.resolution && <span className="font-mono text-[11px] text-muted-foreground">{info.resolution}</span>}
      {info.note && <span className="text-xs text-muted-foreground">{info.note}</span>}
    </div>
  );
}

/** A borderless select, as the device language and text size are drawn. */
function Choice({ label, icon: Icon, value, options }: { label: string; icon: LucideIcon; value: string; options: string[] }) {
  return (
    <Select defaultValue={value}>
      <SelectTrigger aria-label={label} className="h-[30px] border-0 px-2 text-xs hover:bg-accent">
        <Icon className="size-[15px] text-muted-foreground" />
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {options.map((option) => (
          <SelectItem key={option} value={option}>
            {option}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  );
}
