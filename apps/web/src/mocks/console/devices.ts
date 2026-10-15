export type Availability = "available" | "in-use" | "maintenance";

/** A row of the Devices table. */
export interface CloudDevice {
  name: string;
  /** The brand filter it falls under, e.g. iPhone for Apple devices. */
  brand: string;
  /** The line under the name, e.g. "Apple · cloud simulator". */
  maker: string;
  type: "Real" | "Virtual";
  os: string;
  country: string;
  /** City or host after the country, when there is one. */
  city?: string;
  availability: Availability;
  /** People queued for a device in use. */
  waiting?: number;
  favorite: boolean;
}

/** Devices in the whole catalog, of which the table shows a page. */
export const catalogSize = 64;

export const brandCounts = [
  { brand: "Samsung", count: 14 },
  { brand: "Xiaomi", count: 11 },
  { brand: "OPPO", count: 9 },
  { brand: "vivo", count: 8 },
  { brand: "realme", count: 6 },
  { brand: "iPhone", count: 10 },
  { brand: "Pixel", count: 6 },
];

export const devices: CloudDevice[] = [
  {
    name: "Galaxy A55", brand: "Samsung", maker: "Samsung", type: "Real", os: "Android 14",
    country: "Indonesia", city: "Jakarta", availability: "available", favorite: true,
  },
  {
    name: "Galaxy S24", brand: "Samsung", maker: "Samsung", type: "Real", os: "Android 14",
    country: "Vietnam", city: "Ho Chi Minh City", availability: "in-use", waiting: 2, favorite: false,
  },
  {
    name: "Redmi Note 13", brand: "Xiaomi", maker: "Xiaomi", type: "Real", os: "Android 14",
    country: "Vietnam", city: "Ho Chi Minh City", availability: "available", favorite: true,
  },
  {
    name: "Reno11 F", brand: "OPPO", maker: "OPPO", type: "Real", os: "Android 14",
    country: "Thailand", city: "Bangkok", availability: "available", favorite: false,
  },
  {
    name: "V30", brand: "vivo", maker: "vivo", type: "Real", os: "Android 14",
    country: "India", city: "Mumbai", availability: "available", favorite: false,
  },
  {
    name: "12 Pro+", brand: "realme", maker: "realme", type: "Real", os: "Android 14",
    country: "Philippines", city: "Manila", availability: "maintenance", favorite: false,
  },
  {
    name: "iPhone 13", brand: "iPhone", maker: "Apple", type: "Real", os: "iOS 17.6",
    country: "Japan", city: "Tokyo", availability: "available", favorite: false,
  },
  {
    name: "iPhone 15 Pro", brand: "iPhone", maker: "Apple · cloud simulator", type: "Virtual", os: "iOS 18.0",
    country: "Singapore", city: "your Mac hosts", availability: "available", favorite: true,
  },
  {
    name: "Pixel 8", brand: "Pixel", maker: "Google · emulator", type: "Virtual", os: "Android 14",
    country: "Singapore", availability: "available", favorite: true,
  },
];
