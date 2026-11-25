import { fireEvent, render, screen, within } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { I18nProvider } from "@/i18n";
import { DataTable } from "@/components/data/data-table";

const rows = [
  { id: "a", amount: 10 },
  { id: "b", amount: 30 },
  { id: "c", amount: 20 },
];

function setup(extra = {}) {
  const onRowClick = vi.fn();
  render(
    <I18nProvider initial="en">
      <DataTable rows={rows} rowKey={(r) => r.id} onRowClick={onRowClick} columns={[{ key: "id", header: "Id", cell: (r) => r.id }, { key: "amount", header: "Amount", cell: (r) => r.amount, sortValue: (r) => r.amount }]} {...extra} />
    </I18nProvider>,
  );
  return { onRowClick };
}

describe("DataTable", () => {
  it("sorts by a sortable column and exposes aria-sort", () => {
    setup();
    fireEvent.click(screen.getByRole("button", { name: /Amount/ }));
    const cells = screen.getAllByRole("row").slice(1).map((r) => within(r).getAllByRole("cell")[1]!.textContent);
    expect(cells).toEqual(["30", "20", "10"]);
    expect(screen.getByRole("columnheader", { name: /Amount/ })).toHaveAttribute("aria-sort", "descending");
  });

  it("rows are keyboard accessible", () => {
    const { onRowClick } = setup();
    fireEvent.keyDown(screen.getAllByRole("row")[1]!, { key: "Enter" });
    expect(onRowClick).toHaveBeenCalledWith(rows[0]);
  });

  it("shows an empty state", () => {
    render(
      <I18nProvider initial="en">
        <DataTable rows={[]} rowKey={() => "x"} columns={[]} empty={{ title: "Nothing here" }} />
      </I18nProvider>,
    );
    expect(screen.getByText("Nothing here")).toBeInTheDocument();
  });
});
