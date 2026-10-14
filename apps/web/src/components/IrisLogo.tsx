/** The Iris mark: a ring, a pupil and a glint. */
export function IrisLogo({ size = 20, className }: { size?: number; className?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true" className={className}>
      <circle cx="12" cy="12" r="9.5" fill="none" stroke="#5b5bd6" strokeWidth="2.5" />
      <circle cx="12" cy="12" r="4.5" fill="#5b5bd6" />
      <circle cx="13.6" cy="10.4" r="1.3" fill="#ffffff" />
    </svg>
  );
}
