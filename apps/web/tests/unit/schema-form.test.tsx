import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { I18nProvider } from "@/i18n";
import { knownPaths, schemaFor, validateLocal } from "@/features/configuration/schema";
import { SchemaForm } from "@/features/configuration/schema-form";

const doc = {
  apiVersion: "satops.io/v1alpha1",
  kind: "Environment",
  metadata: { name: "lab" },
  spec: { network: { type: "regtest", nodes: 2 }, safety: { allowMainnet: false, allowPublicPeers: false } },
};

describe("configuration contract", () => {
  it("accepts a valid Environment and rejects mainnet and unknown fields", () => {
    expect(validateLocal(doc)).toEqual([]);
    const bad = structuredClone(doc) as Record<string, unknown> & { spec: Record<string, unknown> };
    (bad.spec.network as Record<string, unknown>).type = "mainnet";
    bad.spec.extra = true;
    const issues = validateLocal(bad).map((i) => i.path + " " + i.message);
    expect(issues.join("\n")).toMatch(/network\/type/);
    expect(issues.join("\n")).toMatch(/unknown field "extra"/);
  });

  it("detects fields the form does not know so they are preserved, not dropped", () => {
    expect(knownPaths(schemaFor("Environment"), { ...doc, spec: { ...doc.spec, futureField: 1 } })).toEqual(["/spec/futureField"]);
  });

  it("form edits change only the edited field and keep the rest of the document", () => {
    const onChange = vi.fn();
    render(
      <I18nProvider initial="en">
        <SchemaForm schema={schemaFor("Environment")!.properties!.spec!} value={doc.spec as never} onChange={onChange} path="/spec" errors={{}} />
      </I18nProvider>,
    );
    fireEvent.change(screen.getByLabelText(/^Nodes/), { target: { value: "3" } });
    expect(onChange).toHaveBeenCalledWith({ ...doc.spec, network: { type: "regtest", nodes: 3 } });
  });
});
