import { Dialog as D, DropdownMenu as DM } from "radix-ui";
import { X } from "lucide-react";
import { useState } from "react";
import { useI18n } from "@/i18n";
import { cn } from "@/lib/utils";
import { Button } from "./button";

export function Sheet({
  open,
  onOpenChange,
  title,
  description,
  children,
  footer,
  width = 560,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  title: string;
  description?: React.ReactNode;
  children: React.ReactNode;
  footer?: React.ReactNode;
  width?: number;
}) {
  const { t } = useI18n();
  return (
    <D.Root open={open} onOpenChange={onOpenChange}>
      <D.Portal>
        <D.Overlay className="anim-overlay fixed inset-0 z-40 bg-overlay" />
        <D.Content style={{ maxWidth: width }} className="anim-sheet fixed inset-y-0 right-0 z-50 flex w-full flex-col bg-surface shadow-pop outline-none">
          <header className="flex items-start gap-3 px-4 pb-4 pt-5 sm:px-6">
            <div className="flex min-w-0 flex-1 flex-col gap-1">
              <D.Title className="font-heading text-lg font-semibold text-text">{title}</D.Title>
              {description ? (
                <D.Description className="text-[13px] text-text-muted">{description}</D.Description>
              ) : (
                <D.Description className="sr-only">{title}</D.Description>
              )}
            </div>
            <D.Close className="flex size-9 items-center justify-center rounded-md text-text-muted hover:bg-surface-2 hover:text-text" aria-label={t("common.close")}>
              <X size={18} />
            </D.Close>
          </header>
          <div className="flex-1 overflow-y-auto px-4 pb-6 sm:px-6">{children}</div>
          {footer ? <footer className="flex flex-wrap justify-end gap-3 bg-surface-2/60 px-4 py-4 sm:px-6">{footer}</footer> : null}
        </D.Content>
      </D.Portal>
    </D.Root>
  );
}

export function Dialog({
  open,
  onOpenChange,
  title,
  description,
  children,
  className,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  title: string;
  description?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <D.Root open={open} onOpenChange={onOpenChange}>
      <D.Portal>
        <D.Overlay className="anim-overlay fixed inset-0 z-40 bg-overlay" />
        <D.Content
          className={cn(
            "anim-dialog fixed left-1/2 top-1/2 z-50 flex max-h-[calc(100dvh-32px)] w-[calc(100%-32px)] max-w-md -translate-x-1/2 -translate-y-1/2 flex-col gap-4 overflow-y-auto rounded-lg bg-surface p-5 shadow-pop outline-none sm:top-[42%] sm:p-6",
            className,
          )}
        >
          <div className="flex flex-col gap-1">
            <D.Title className="font-heading text-lg font-semibold text-text">{title}</D.Title>
            {description ? (
              <D.Description className="text-sm text-text-secondary">{description}</D.Description>
            ) : (
              <D.Description className="sr-only">{title}</D.Description>
            )}
          </div>
          {children}
        </D.Content>
      </D.Portal>
    </D.Root>
  );
}

export function ConfirmDialog({
  open,
  onOpenChange,
  title,
  description,
  confirmLabel,
  danger,
  onConfirm,
  requireReason,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  title: string;
  description?: string;
  confirmLabel?: string;
  danger?: boolean;
  onConfirm: (reason: string) => Promise<unknown> | void;
  requireReason?: string;
}) {
  const { t } = useI18n();
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  return (
    <Dialog open={open} onOpenChange={onOpenChange} title={title} description={description}>
      {requireReason ? (
        <label className="flex flex-col gap-1.5 text-[13px] font-medium">
          {requireReason}
          <textarea
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            className="min-h-20 rounded-md bg-surface-2 p-2.5 text-[13px] outline-none focus:ring-2 focus:ring-primary/60"
          />
        </label>
      ) : null}
      <div className="flex justify-end gap-2">
        <Button variant="ghost" onClick={() => onOpenChange(false)}>
          {t("common.cancel")}
        </Button>
        <Button
          variant={danger ? "danger" : "primary"}
          loading={busy}
          disabled={Boolean(requireReason) && reason.trim() === ""}
          onClick={async () => {
            setBusy(true);
            try {
              await onConfirm(reason.trim());
              onOpenChange(false);
              setReason("");
            } finally {
              setBusy(false);
            }
          }}
        >
          {confirmLabel ?? t("common.confirm")}
        </Button>
      </div>
    </Dialog>
  );
}

export const Menu = DM.Root;
export const MenuTrigger = DM.Trigger;

export function MenuContent({ children, align = "end", className }: { children: React.ReactNode; align?: "start" | "end" | "center"; className?: string }) {
  return (
    <DM.Portal>
      <DM.Content align={align} sideOffset={6} className={cn("anim-menu z-50 min-w-48 rounded-lg bg-surface p-1 shadow-pop", className)}>
        {children}
      </DM.Content>
    </DM.Portal>
  );
}

export function MenuItem({ children, onSelect, danger, disabled }: { children: React.ReactNode; onSelect?: () => void; danger?: boolean; disabled?: boolean }) {
  return (
    <DM.Item
      disabled={disabled}
      onSelect={onSelect}
      className={cn(
        "flex cursor-pointer items-center gap-2.5 rounded-md px-2.5 py-2 text-sm outline-none data-[disabled]:pointer-events-none data-[highlighted]:bg-surface-2 data-[disabled]:opacity-50 [&_svg]:size-4",
        danger ? "text-danger" : "text-text",
      )}
    >
      {children}
    </DM.Item>
  );
}

export const MenuSeparator = () => <DM.Separator className="my-1 h-px bg-surface-3" />;
export const MenuLabel = ({ children }: { children: React.ReactNode }) => <DM.Label className="px-2.5 py-1.5 text-xs text-text-muted">{children}</DM.Label>;
