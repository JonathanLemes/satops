import { ArrowDown, ArrowUp, ChevronsUpDown, Inbox } from "lucide-react";
import { useMemo, useState } from "react";
import { useI18n } from "@/i18n";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { EmptyState, ErrorState, LoadingState } from "@/components/ui/misc";

export interface Column<T> {
  key: string;
  header: React.ReactNode;
  cell: (row: T) => React.ReactNode;
  sortValue?: (row: T) => string | number | null | undefined;
  align?: "left" | "right";
  className?: string;
  primary?: boolean;
}

export function DataTable<T>({
  rows,
  columns,
  rowKey,
  onRowClick,
  loading,
  error,
  onRetry,
  empty,
  hasMore,
  onLoadMore,
  loadingMore,
  pageSize,
  caption,
  className,
}: {
  rows: T[] | undefined;
  columns: Column<T>[];
  rowKey: (row: T) => string;
  onRowClick?: (row: T) => void;
  loading?: boolean;
  error?: unknown;
  onRetry?: () => void;
  empty?: { title: string; description?: string; action?: React.ReactNode };
  hasMore?: boolean;
  onLoadMore?: () => void;
  loadingMore?: boolean;
  pageSize?: number;
  caption?: string;
  className?: string;
}) {
  const { t } = useI18n();
  const [sort, setSort] = useState<{ key: string; dir: "asc" | "desc" } | null>(null);
  const [page, setPage] = useState(0);

  const sorted = useMemo(() => {
    if (!rows) return [];
    const col = sort && columns.find((c) => c.key === sort.key);
    if (!col?.sortValue) return rows;
    const factor = sort?.dir === "asc" ? 1 : -1;
    return [...rows].sort((a, b) => {
      const av = col.sortValue!(a);
      const bv = col.sortValue!(b);
      if (av === bv) return 0;
      if (av === null || av === undefined) return 1;
      if (bv === null || bv === undefined) return -1;
      return av > bv ? factor : -factor;
    });
  }, [rows, sort, columns]);

  const pages = pageSize ? Math.max(1, Math.ceil(sorted.length / pageSize)) : 1;
  const visible = pageSize ? sorted.slice(page * pageSize, page * pageSize + pageSize) : sorted;

  if (error && !rows?.length)
    return <ErrorState onRetry={onRetry} message={error instanceof Error ? error.message : undefined} />;
  if (loading && !rows) return <LoadingState />;
  if (!sorted.length)
    return (
      <EmptyState
        icon={Inbox}
        title={empty?.title ?? t("common.noResults")}
        description={empty?.description}
        action={empty?.action}
      />
    );

  return (
    <div className={cn("min-w-0", className)}>
      <div className="overflow-x-auto">
        <table className="data-table">
          {caption ? <caption className="sr-only">{caption}</caption> : null}
          <thead>
            <tr>
              {columns.map((c) => {
                const active = sort?.key === c.key;
                return (
                  <th
                    key={c.key}
                    scope="col"
                    className={cn(c.align === "right" && "text-right", c.className)}
                    aria-sort={active ? (sort?.dir === "asc" ? "ascending" : "descending") : undefined}
                  >
                    {c.sortValue ? (
                      <button
                        type="button"
                        className={cn(
                          "inline-flex items-center gap-1 hover:text-text",
                          c.align === "right" && "flex-row-reverse",
                        )}
                        onClick={() =>
                          setSort(
                            active && sort?.dir === "desc" ? { key: c.key, dir: "asc" } : { key: c.key, dir: "desc" },
                          )
                        }
                      >
                        {c.header}
                        {active ? (
                          sort?.dir === "asc" ? (
                            <ArrowUp size={12} />
                          ) : (
                            <ArrowDown size={12} />
                          )
                        ) : (
                          <ChevronsUpDown size={12} className="opacity-50" />
                        )}
                      </button>
                    ) : (
                      c.header
                    )}
                  </th>
                );
              })}
            </tr>
          </thead>
          <tbody>
            {visible.map((row) => (
              <tr
                key={rowKey(row)}
                data-clickable={onRowClick ? "true" : undefined}
                tabIndex={onRowClick ? 0 : undefined}
                onClick={onRowClick ? () => onRowClick(row) : undefined}
                onKeyDown={
                  onRowClick
                    ? (e) => {
                        if (e.key === "Enter") onRowClick(row);
                      }
                    : undefined
                }
              >
                {columns.map((c) => (
                  <td
                    key={c.key}
                    className={cn(c.align === "right" && "text-right", c.primary && "cell-primary", c.className)}
                  >
                    {c.cell(row)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {pageSize && pages > 1 ? (
        <nav
          className="flex items-center justify-between gap-3 px-4 py-3 text-xs text-text-secondary"
          aria-label="pagination"
        >
          <span>
            {page + 1} / {pages}
          </span>
          <div className="flex gap-2">
            <Button size="sm" disabled={page === 0} onClick={() => setPage((p) => p - 1)}>
              {t("common.previous")}
            </Button>
            <Button size="sm" disabled={page >= pages - 1} onClick={() => setPage((p) => p + 1)}>
              {t("common.next")}
            </Button>
          </div>
        </nav>
      ) : null}
      {hasMore && onLoadMore ? (
        <div className="flex justify-center p-4">
          <Button onClick={onLoadMore} loading={loadingMore}>
            {t("common.loadMore")}
          </Button>
        </div>
      ) : null}
    </div>
  );
}
