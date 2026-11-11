// Lists DevSMS templates (read-only). Prints id, name, status, placeholders
// and text; never prints the API token. Used by the "List DevSMS templates"
// GitHub Actions workflow. Usage: DEVSMS_API_TOKEN=… node list-templates.mjs [summary.md]
import { appendFileSync } from "node:fs";
import { DevSmsClient } from "../src/devsms";
import { ApiError } from "../src/errors";

const token = process.env.DEVSMS_API_TOKEN?.trim() ?? "";
if (!token) {
  console.error("::error::DEVSMS_API_TOKEN secret is missing");
  process.exit(1);
}

const summary = process.argv[2];
const cell = (value: string) => value.replace(/\|/g, "\\|").replace(/\r?\n/g, " ⏎ ");

try {
  const templates = await new DevSmsClient(token).listTemplates();
  console.log(`DevSMS templates: ${templates.length}`);
  for (const t of templates) {
    console.log(`- id=${t.id} | name=${t.name} | status=${t.status ?? "-"} | placeholders=${t.placeholders.join(", ") || "-"}`);
    console.log(`  text: ${t.text}`);
  }
  if (summary) {
    const rows = templates.map(
      (t) =>
        `| ${t.id} | ${cell(t.name)} | ${cell(t.status ?? "-")} | ${cell(t.placeholders.join(", ") || "-")} | ${cell(t.text)} |`,
    );
    appendFileSync(
      summary,
      [
        `### DevSMS shablonlari (${templates.length})`,
        "",
        "| ID | Nomi | Holati | Parametrlar | Matn |",
        "|---|---|---|---|---|",
        ...rows,
        "",
        "Shablonlar faqat o'qildi; hech biri o'zgartirilmadi yoki o'chirilmadi.",
        "",
      ].join("\n"),
    );
  }
} catch (error) {
  const message = error instanceof ApiError ? `${error.reason}: ${error.message}` : String((error as Error)?.message);
  console.error(`::error::DevSMS templates could not be read (${message})`);
  process.exit(1);
}
