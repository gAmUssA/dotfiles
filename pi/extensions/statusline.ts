/**
 * Footer that renders the shared agent status line (claude/statusline.sh).
 *
 * pi has no "run a command for the status line" setting, only setFooter(), so
 * this builds the Claude-shaped JSON the script reads, runs it off the render
 * path, and paints the cached output. Linked into ~/.pi/agent/extensions/ by
 * agents/statusline-install.sh.
 *
 * pi's own footer also lists other extensions' setStatus() texts; they are
 * kept as a last line so replacing the footer does not hide them.
 */

import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";
import { execFile } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

const SCRIPT = join(homedir(), ".claude", "statusline.sh");
const REFRESH_MS = 30_000; // the elapsed-time segment moves while idle

export default function (pi: ExtensionAPI) {
	const startedAt = Date.now();
	let lines: string[] = [];
	let running = false;
	let again = false;
	let requestRender: (() => void) | undefined;
	let timer: ReturnType<typeof setInterval> | undefined;

	function payload(ctx: ExtensionContext) {
		let cost = 0;
		for (const e of ctx.sessionManager.getBranch()) {
			if (e.type === "message" && e.message.role === "assistant") {
				cost += (e.message as AssistantMessage).usage?.cost?.total ?? 0;
			}
		}
		const usage = ctx.getContextUsage();
		return {
			session_id: ctx.sessionManager.getSessionId?.(),
			cwd: ctx.cwd,
			model: ctx.model ? { id: ctx.model.id, display_name: ctx.model.name || ctx.model.id } : undefined,
			workspace: { current_dir: ctx.cwd },
			cost: { total_duration_ms: Date.now() - startedAt, total_cost_usd: cost },
			context_window: usage
				? { context_window_size: usage.contextWindow, used_percentage: usage.percent ?? 0 }
				: undefined,
		};
	}

	// One run at a time; a change landing mid-run schedules exactly one more.
	function refresh(ctx: ExtensionContext) {
		if (running) {
			again = true;
			return;
		}
		running = true;
		const child = execFile(SCRIPT, { cwd: ctx.cwd, timeout: 10_000 }, (err, stdout) => {
			running = false;
			if (!err) lines = stdout.replace(/\n+$/, "").split("\n");
			requestRender?.();
			if (again) {
				again = false;
				refresh(ctx);
			}
		});
		child.stdin?.end(JSON.stringify(payload(ctx)));
	}

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		ctx.ui.setFooter((tui, theme, footerData) => {
			requestRender = () => tui.requestRender();
			const unsub = footerData.onBranchChange(() => refresh(ctx));
			return {
				dispose() {
					unsub();
					requestRender = undefined;
				},
				invalidate() {},
				render(width: number): string[] {
					const out = lines.map((l) => truncateToWidth(l, width));
					const statuses = [...footerData.getExtensionStatuses().values()].filter(Boolean);
					if (statuses.length) out.push(truncateToWidth(theme.fg("dim", statuses.join("  ")), width));
					return out;
				},
			};
		});
		refresh(ctx);
		timer = setInterval(() => refresh(ctx), REFRESH_MS);
		timer.unref?.();
	});

	for (const ev of ["turn_end", "agent_end", "model_select", "session_compact"] as const) {
		pi.on(ev, (_event, ctx) => {
			if (ctx.mode === "tui") refresh(ctx);
		});
	}

	pi.on("session_shutdown", () => {
		if (timer) clearInterval(timer);
		timer = undefined;
	});
}
