import { forwardRef, useId } from "react";
import { cn } from "@/lib/utils";

const control =
  "w-full rounded-md border border-transparent bg-surface-2 px-3 text-[13px] text-text placeholder:text-text-muted outline-none transition-[box-shadow,background-color] hover:bg-surface-3/70 focus:bg-surface focus:ring-2 focus:ring-primary/60 disabled:opacity-60 aria-[invalid=true]:ring-2 aria-[invalid=true]:ring-danger/70";

type ControlStyle = { variant?: "solid" | "outline"; controlSize?: "sm" | "md" | "lg" | "xl" };
const controlSizes = { sm: "h-7 px-2", md: "h-8 px-2.5", lg: "h-9 px-3", xl: "h-10 px-3.5" };
const controlStyles = { solid: "border-transparent bg-surface-2", outline: "border-border-strong bg-surface" };

export const Input = forwardRef<HTMLInputElement, React.InputHTMLAttributes<HTMLInputElement> & ControlStyle>(
  function Input({ className, variant = "solid", controlSize = "lg", ...props }, ref) {
    return (
      <input
        ref={ref}
        className={cn(control, controlSizes[controlSize], controlStyles[variant], className)}
        {...props}
      />
    );
  },
);

export const Textarea = forwardRef<
  HTMLTextAreaElement,
  React.TextareaHTMLAttributes<HTMLTextAreaElement> & Pick<ControlStyle, "variant">
>(function Textarea({ className, variant = "solid", ...props }, ref) {
  return (
    <textarea
      ref={ref}
      className={cn(control, "min-h-24 resize-y py-2.5 leading-relaxed", controlStyles[variant], className)}
      {...props}
    />
  );
});

export const Select = forwardRef<HTMLSelectElement, React.SelectHTMLAttributes<HTMLSelectElement> & ControlStyle>(
  function Select({ className, children, variant = "outline", controlSize = "md", style, ...props }, ref) {
    return (
      <select
        ref={ref}
        className={cn(control, controlSizes[controlSize], controlStyles[variant], "appearance-none pr-9", className)}
        style={{
          backgroundImage:
            "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='%2360646c' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpath d='m6 9 6 6 6-6'/%3E%3C/svg%3E\")",
          backgroundSize: "16px",
          backgroundPosition: "right 10px center",
          backgroundRepeat: "no-repeat",
          ...style,
        }}
        {...props}
      >
        {children}
      </select>
    );
  },
);

export function Field({
  label,
  hint,
  error,
  children,
  className,
  required,
}: {
  label: string;
  hint?: string;
  error?: string;
  children: (id: string, describedBy?: string) => React.ReactNode;
  className?: string;
  required?: boolean;
}) {
  const id = useId();
  const descId = hint || error ? `${id}-desc` : undefined;
  return (
    <div className={cn("flex min-w-0 flex-col gap-1.5", className)}>
      <label htmlFor={id} className="text-[13px] font-medium text-text">
        {label}
        {required ? <span className="text-danger"> *</span> : null}
      </label>
      {children(id, descId)}
      {error ? (
        <p id={descId} role="alert" className="text-xs text-danger">
          {error}
        </p>
      ) : hint ? (
        <p id={descId} className="text-xs text-text-muted">
          {hint}
        </p>
      ) : null}
    </div>
  );
}

export function Checkbox({
  checked,
  onChange,
  label,
  disabled,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  label: React.ReactNode;
  disabled?: boolean;
}) {
  return (
    <label className="flex cursor-pointer items-start gap-2.5 text-[13px] text-text-secondary">
      <input
        type="checkbox"
        disabled={disabled}
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        className="mt-0.5 size-[18px] shrink-0 cursor-pointer accent-[var(--primary)]"
      />
      <span>{label}</span>
    </label>
  );
}

export function Switch({
  checked,
  onChange,
  label,
}: {
  checked: boolean;
  onChange: (v: boolean) => void;
  label: string;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      onClick={() => onChange(!checked)}
      className="flex items-center gap-3 text-left text-[13px] text-text-secondary"
    >
      <span
        className={cn(
          "relative h-5 w-9 shrink-0 rounded-full transition-colors",
          checked ? "bg-primary" : "bg-border-strong",
        )}
      >
        <span
          className={cn(
            "absolute left-0 top-0.5 size-4 rounded-full bg-white transition-transform",
            checked ? "translate-x-[18px]" : "translate-x-0.5",
          )}
        />
      </span>
      {label}
    </button>
  );
}
