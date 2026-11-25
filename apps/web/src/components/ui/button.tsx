import { forwardRef } from "react";
import { cn } from "@/lib/utils";

type Variant = "primary" | "secondary" | "ghost" | "danger" | "soft" | "outline";
type Size = "sm" | "md" | "lg" | "icon" | "icon-sm" | "xl";

const variants: Record<Variant, string> = {
  primary: "bg-primary text-primary-foreground hover:bg-primary-hover [&_svg]:text-primary-foreground",
  outline: "border border-border-strong bg-surface text-text hover:bg-surface-2",
  secondary: "border border-surface-3 bg-surface-3 text-text hover:brightness-95",
  ghost: "text-text-secondary hover:bg-surface-2 hover:text-text",
  danger: "bg-danger text-white hover:brightness-95 dark:text-[#2e1210]",
  soft: "bg-primary-soft text-primary-soft-foreground hover:brightness-[0.97] dark:hover:brightness-110",
};

const sizes: Record<Size, string> = {
  sm: "h-7 justify-center px-2 text-xs gap-2",
  md: "h-8 justify-center px-2.5 text-xs gap-2",
  lg: "h-9 justify-center px-3 text-xs gap-2",
  xl: "h-10 justify-center px-4 text-xs gap-2",
  icon: "size-9 justify-center",
  "icon-sm": "size-7 justify-center",
};

export type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant; size?: Size; loading?: boolean };

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = "outline", size = "md", loading, className, children, disabled, type = "button", ...props },
  ref,
) {
  return (
    <button
      ref={ref}
      type={type}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      className={cn(
        "inline-flex shrink-0 select-none items-center whitespace-nowrap rounded-lg font-semibold transition-[background-color,color,filter,transform] active:scale-[0.98] disabled:pointer-events-none disabled:opacity-50 [&_svg]:size-4 [&_svg]:shrink-0",
        variants[variant],
        sizes[size],
        className,
      )}
      {...props}
    >
      {loading ? <Spinner /> : null}
      {children}
    </button>
  );
});

export function Spinner({ className }: { className?: string }) {
  return <span aria-hidden className={cn("inline-block size-4 animate-spin rounded-full border-2 border-current border-r-transparent", className)} />;
}
