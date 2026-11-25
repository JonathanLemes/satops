import { Plus, Trash2 } from "lucide-react";
import { useEffect, useId, useState } from "react";
import { useI18n } from "@/i18n";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Checkbox, Input, Select, Switch, Textarea } from "@/components/ui/input";
import { Tag } from "@/components/ui/misc";
import type { JsonSchema } from "./schema";

type Json = string | number | boolean | null | Json[] | { [key: string]: Json };

function humanize(key: string) {
  return key.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/^./, (c) => c.toUpperCase());
}

function typeOf(schema: JsonSchema): string | undefined {
  if (schema.const !== undefined) return "const";
  if (schema.enum) return "enum";
  return Array.isArray(schema.type) ? schema.type[0] : schema.type;
}

function setKey(obj: Record<string, Json> | undefined, key: string, value: Json | undefined): Record<string, Json> {
  const next = { ...(obj ?? {}) };
  if (value === undefined || value === "") delete next[key];
  else next[key] = value;
  return next;
}

export function SchemaForm({
  schema,
  value,
  onChange,
  path,
  errors,
}: {
  schema: JsonSchema;
  value: Record<string, Json> | undefined;
  onChange: (v: Record<string, Json>) => void;
  path: string;
  errors: Record<string, string>;
}) {
  const props = schema.properties ?? {};
  return (
    <div className="flex flex-col gap-4">
      {Object.entries(props).map(([key, child]) => (
        <SchemaField
          key={key}
          name={key}
          schema={child}
          required={schema.required?.includes(key) ?? false}
          value={value?.[key]}
          onChange={(v) => onChange(setKey(value, key, v))}
          path={`${path}/${key}`}
          errors={errors}
        />
      ))}
    </div>
  );
}

function SchemaField({
  name,
  schema,
  required,
  value,
  onChange,
  path,
  errors,
}: {
  name: string;
  schema: JsonSchema;
  required: boolean;
  value: Json | undefined;
  onChange: (v: Json | undefined) => void;
  path: string;
  errors: Record<string, string>;
}) {
  const id = useId();
  const type = typeOf(schema);
  const error = errors[path];
  const label = (
    <label htmlFor={id} className="flex items-baseline gap-2 text-[13px] font-medium text-text">
      {humanize(name)}
      {required ? <span className="text-danger">*</span> : null}
      <code className="text-[11px] font-normal text-text-muted">{name}</code>
    </label>
  );
  const hint = schema.description ? <p className="text-xs text-text-muted">{schema.description}</p> : null;
  const err = error ? (
    <p role="alert" className="text-xs text-danger">
      {error}
    </p>
  ) : null;

  if (type === "object" && schema.properties) {
    return (
      <fieldset className={cn("flex flex-col gap-4 rounded-md border border-border p-4", error && "border-danger")}>
        <legend className="px-1 text-[13px] font-semibold">
          {humanize(name)} {required ? <span className="text-danger">*</span> : null}
        </legend>
        {hint}
        {err}
        <SchemaForm
          schema={schema}
          value={value as Record<string, Json> | undefined}
          onChange={onChange}
          path={path}
          errors={errors}
        />
      </fieldset>
    );
  }

  if (type === "array" && schema.items && (typeOf(schema.items) === "object" || schema.items.properties)) {
    const list = (Array.isArray(value) ? value : []) as Record<string, Json>[];
    return (
      <fieldset className="flex flex-col gap-3 rounded-md border border-border p-4">
        <legend className="px-1 text-[13px] font-semibold">
          {humanize(name)} {required ? <span className="text-danger">*</span> : null}
        </legend>
        {err}
        {list.map((item, i) => (
          <div key={i} className="flex flex-col gap-3 rounded-md bg-surface-2 p-3">
            <div className="flex items-center justify-between">
              <span className="text-xs font-medium text-text-secondary">#{i + 1}</span>
              <Button
                size="icon-sm"
                variant="ghost"
                aria-label={`remove ${name} ${i + 1}`}
                onClick={() => onChange(list.filter((_, j) => j !== i))}
              >
                <Trash2 />
              </Button>
            </div>
            {schema.items!.properties ? (
              <SchemaForm
                schema={schema.items!}
                value={item}
                onChange={(v) => onChange(list.map((x, j) => (j === i ? v : x)))}
                path={`${path}/${i}`}
                errors={errors}
              />
            ) : (
              <JsonField
                value={item}
                onChange={(v) => onChange(list.map((x, j) => (j === i ? (v as Record<string, Json>) : x)))}
              />
            )}
          </div>
        ))}
        <Button size="sm" className="self-start" onClick={() => onChange([...list, {}])}>
          <Plus /> {humanize(name)}
        </Button>
      </fieldset>
    );
  }

  if (type === "array" && schema.items?.enum) {
    const list = (Array.isArray(value) ? value : []) as string[];
    return (
      <fieldset className="flex flex-col gap-2">
        <legend className="mb-1 text-[13px] font-medium">{humanize(name)}</legend>
        {err}
        <div className="grid gap-1.5 sm:grid-cols-2">
          {schema.items.enum.map((opt) => (
            <Checkbox
              key={String(opt)}
              checked={list.includes(String(opt))}
              onChange={(on) => onChange(on ? [...list, String(opt)] : list.filter((x) => x !== opt))}
              label={<span className="font-mono text-xs">{String(opt)}</span>}
            />
          ))}
        </div>
      </fieldset>
    );
  }

  if (type === "array") {
    const list = (Array.isArray(value) ? value : []) as Json[];
    return (
      <div className="flex flex-col gap-1.5">
        {label}
        <Textarea
          id={id}
          className="min-h-20 font-mono text-xs"
          value={list.join("\n")}
          aria-invalid={!!error}
          onChange={(e) => {
            const items = e.target.value
              .split("\n")
              .map((s) => s.trim())
              .filter(Boolean);
            onChange(items.length ? items : undefined);
          }}
        />
        {hint}
        {err}
      </div>
    );
  }

  if (type === "object") {
    return (
      <div className="flex flex-col gap-1.5">
        {label}
        <JsonField id={id} value={value ?? null} onChange={(v) => onChange(v ?? undefined)} />
        {hint}
        {err}
      </div>
    );
  }

  if (type === "const") {
    return (
      <div className="flex items-center justify-between gap-3">
        {label}
        <Tag tone="warning" dot={false}>
          {String(schema.const)}
        </Tag>
      </div>
    );
  }

  if (type === "boolean") {
    return (
      <div className="flex flex-col gap-1">
        <Switch checked={value === true} onChange={(v) => onChange(v)} label={humanize(name)} />
        {err}
      </div>
    );
  }

  if (type === "enum") {
    return (
      <div className="flex flex-col gap-1.5">
        {label}
        <Select
          id={id}
          value={value === undefined || value === null ? "" : String(value)}
          aria-invalid={!!error}
          onChange={(e) => onChange(e.target.value || undefined)}
        >
          {!required ? <option value="">-</option> : null}
          {schema.enum!.map((opt) => (
            <option key={String(opt)} value={String(opt)}>
              {String(opt)}
            </option>
          ))}
        </Select>
        {hint}
        {err}
      </div>
    );
  }

  const numeric = type === "integer" || type === "number";
  return (
    <div className="flex flex-col gap-1.5">
      {label}
      <Input
        id={id}
        type={numeric ? "number" : "text"}
        min={schema.minimum}
        max={schema.maximum}
        step={type === "integer" ? 1 : undefined}
        value={value === undefined || value === null ? "" : String(value)}
        aria-invalid={!!error}
        placeholder={schema.pattern?.includes("ms|s|m") ? "30s" : undefined}
        onChange={(e) => {
          const raw = e.target.value;
          if (raw === "") return onChange(undefined);
          onChange(numeric ? Number(raw) : raw);
        }}
      />
      {hint}
      {err}
    </div>
  );
}

function JsonField({ id, value, onChange }: { id?: string; value: Json; onChange: (v: Json) => void }) {
  const { t } = useI18n();
  const [text, setText] = useState(() => JSON.stringify(value ?? {}, null, 2));
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    setText(JSON.stringify(value ?? {}, null, 2));
  }, [value]);
  return (
    <>
      <Textarea
        id={id}
        className="min-h-24 font-mono text-xs"
        value={text}
        aria-invalid={!!error}
        onChange={(e) => setText(e.target.value)}
        onBlur={() => {
          try {
            onChange(JSON.parse(text) as Json);
            setError(null);
          } catch {
            setError(t("config.parseError"));
          }
        }}
      />
      {error ? <p className="text-xs text-danger">{error}</p> : null}
    </>
  );
}
