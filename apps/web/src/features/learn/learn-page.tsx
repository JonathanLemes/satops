import { BookOpenCheck, FlaskConical, GitCompareArrows, Layers3 } from "lucide-react";
import { Link } from "react-router";
import { useI18n } from "@/i18n";
import { PageHeader, Panel } from "@/components/ui/misc";

export default function LearnPage() {
  const { t } = useI18n();
  const cards = [
    { icon: Layers3, title: t("learn.confirmationsTitle"), body: t("learn.confirmations"), to: "/transactions" },
    { icon: GitCompareArrows, title: t("learn.reconciliationTitle"), body: t("learn.reconciliation"), to: "/reconciliation" },
    { icon: BookOpenCheck, title: t("learn.ledgerTitle"), body: t("learn.ledger"), to: "/engineering/ledger" },
    { icon: FlaskConical, title: t("learn.experimentsTitle"), body: t("learn.experiments"), to: "/engineering/experiments" },
  ];
  return (
    <div className="flex flex-col gap-5">
      <PageHeader title={t("learn.title")} subtitle={t("learn.subtitle")} />
      <div className="grid gap-4 md:grid-cols-2">
        {cards.map((c) => (
          <Panel key={c.title} className="gap-3 p-6">
            <span className="flex size-11 items-center justify-center rounded-xl bg-primary-soft text-primary">
              <c.icon size={22} />
            </span>
            <h2 className="text-lg font-semibold">{c.title}</h2>
            <p className="text-[13px] leading-relaxed text-text-secondary">{c.body}</p>
            <Link to={c.to} className="text-[13px] font-medium text-primary hover:underline">
              {t("common.view")} →
            </Link>
          </Panel>
        ))}
      </div>
    </div>
  );
}
