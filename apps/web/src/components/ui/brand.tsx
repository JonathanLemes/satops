import { cn } from "@/lib/utils";

export function LogoMark({ size = 28, className }: { size?: number; className?: string }) {
  return (
    <svg viewBox="0 0 32 32" width={size} height={size} aria-hidden className={cn("shrink-0", className)}>
      <circle cx="16" cy="16" r="5.5" fill="#f7931a" />
      <ellipse cx="16" cy="16" rx="13" ry="6" fill="none" stroke="#f7931a" strokeWidth="2.2" transform="rotate(-30 16 16)" />
      <circle cx="27.2" cy="9.6" r="2.2" fill="#ffffff" />
    </svg>
  );
}

export function Logo({ height = 24, className }: { height?: number; className?: string }) {
  return (
    <span className={cn("inline-flex items-center gap-2", className)} style={{ height }} role="img" aria-label="SatOps">
      <LogoMark size={height} />
      <span className="font-heading text-[17px] font-semibold tracking-tight" aria-hidden>
        Sat<span className="text-[#f7931a]">Ops</span>
      </span>
    </span>
  );
}
