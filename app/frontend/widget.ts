/*!
 * Ask Anna widget (spec Fase 3) — minimal popup, no framework required.
 *
 * Usage:
 *   <script
 *     src="https://ask.example.com/widget.js"
 *     data-api-base="https://ask.example.com"
 *     defer
 *   ></script>
 *
 * data-api-base defaults to the script's own origin, so on a site served
 * from the same host it can be omitted.
 *
 * Source of truth is this file; it's compiled to public/widget.js via
 * `npm run build` (see package.json). Don't hand-edit the compiled output.
 */

interface AskResponse {
  answer: string;
  sources: string[];
}

interface AskErrorResponse {
  error: string;
}

(function () {
  "use strict";

  const currentScript = document.currentScript as HTMLScriptElement | null;
  const apiBase = currentScript?.dataset.apiBase ?? "";
  const title = currentScript?.dataset.title ?? "Ask Anna";
  const askUrl = apiBase.replace(/\/$/, "") + "/ask";

  const STYLE = `
    #ask-anna-widget * { box-sizing: border-box; }
    #ask-anna-widget { position: fixed; right: 20px; bottom: 20px; z-index: 2147483000; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
    #ask-anna-toggle { width: 56px; height: 56px; border-radius: 50%; border: none; background: #1f2937; color: #fff; font-size: 22px; cursor: pointer; box-shadow: 0 4px 14px rgba(0,0,0,.25); }
    #ask-anna-toggle:hover { background: #111827; }
    #ask-anna-panel { display: none; flex-direction: column; position: fixed; right: 20px; bottom: 88px; width: 340px; max-width: calc(100vw - 40px); height: 460px; max-height: calc(100vh - 120px); background: #fff; border-radius: 12px; box-shadow: 0 10px 40px rgba(0,0,0,.25); overflow: hidden; }
    #ask-anna-panel.open { display: flex; }
    #ask-anna-header { padding: 14px 16px; background: #1f2937; color: #fff; font-weight: 600; display: flex; justify-content: space-between; align-items: center; }
    #ask-anna-close { background: none; border: none; color: #fff; font-size: 18px; cursor: pointer; line-height: 1; }
    #ask-anna-log { flex: 1; overflow-y: auto; padding: 12px 14px; font-size: 14px; color: #111827; }
    #ask-anna-log p { margin: 0 0 10px; white-space: pre-wrap; }
    #ask-anna-log .ask-anna-answer { background: #f3f4f6; border-radius: 8px; padding: 8px 10px; }
    #ask-anna-log .ask-anna-question { font-weight: 600; }
    #ask-anna-log .ask-anna-error { color: #b91c1c; }
    #ask-anna-sources { margin-top: 6px; font-size: 12px; }
    #ask-anna-sources a { color: #2563eb; display: block; text-decoration: none; word-break: break-all; }
    #ask-anna-sources a:hover { text-decoration: underline; }
    #ask-anna-form { display: flex; gap: 6px; padding: 10px; border-top: 1px solid #e5e7eb; }
    #ask-anna-input { flex: 1; resize: none; border: 1px solid #d1d5db; border-radius: 8px; padding: 8px; font-size: 14px; font-family: inherit; height: 40px; }
    #ask-anna-submit { border: none; background: #1f2937; color: #fff; border-radius: 8px; padding: 0 14px; cursor: pointer; font-size: 14px; }
    #ask-anna-submit:disabled { opacity: .5; cursor: default; }
  `;

  type ElementAttrs = Record<string, string> & { text?: string };

  function el<K extends keyof HTMLElementTagNameMap>(
    tag: K,
    attrs?: ElementAttrs,
    children?: Node[]
  ): HTMLElementTagNameMap[K] {
    const node = document.createElement(tag);
    Object.entries(attrs ?? {}).forEach(([ key, value ]) => {
      if (key === "text") {
        node.textContent = value;
      } else {
        node.setAttribute(key, value);
      }
    });
    (children ?? []).forEach((child) => node.appendChild(child));
    return node;
  }

  function appendQuestion(log: HTMLElement, question: string): void {
    log.appendChild(el("p", { class: "ask-anna-question", text: question }));
    log.scrollTop = log.scrollHeight;
  }

  function appendAnswer(log: HTMLElement, text: string, sources: string[]): void {
    const wrapper = el("div", { class: "ask-anna-answer" });
    wrapper.appendChild(el("p", { text }));

    if (sources.length > 0) {
      const sourcesEl = el("div", { id: "ask-anna-sources" });
      sources.forEach((url) => {
        sourcesEl.appendChild(el("a", { href: url, target: "_blank", rel: "noopener noreferrer", text: url }));
      });
      wrapper.appendChild(sourcesEl);
    }

    log.appendChild(wrapper);
    log.scrollTop = log.scrollHeight;
  }

  function appendError(log: HTMLElement, text: string): void {
    log.appendChild(el("p", { class: "ask-anna-error", text }));
    log.scrollTop = log.scrollHeight;
  }

  async function askQuestion(question: string): Promise<AskResponse> {
    const response = await fetch(askUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ question })
    });

    const body = (await response.json()) as AskResponse | AskErrorResponse;

    if (!response.ok) {
      throw new Error("error" in body ? body.error : "Qualcosa e' andato storto.");
    }

    return body as AskResponse;
  }

  function init(): void {
    const style = document.createElement("style");
    style.textContent = STYLE;
    document.head.appendChild(style);

    const root = el("div", { id: "ask-anna-widget" });
    const toggle = el("button", { id: "ask-anna-toggle", type: "button", "aria-label": title, text: "?" });

    const log = el("div", { id: "ask-anna-log" }, [
      el("p", { class: "ask-anna-answer", text: "Chiedimi qualcosa sull'esperienza professionale di Anna." })
    ]);

    const input = el("textarea", { id: "ask-anna-input", placeholder: "Fai una domanda...", rows: "1" });
    const submit = el("button", { id: "ask-anna-submit", type: "submit", text: "Invia" });
    const form = el("form", { id: "ask-anna-form" }, [ input, submit ]);

    const closeBtn = el("button", { id: "ask-anna-close", type: "button", "aria-label": "Chiudi", text: "✕" });
    const header = el("div", { id: "ask-anna-header" }, [ el("span", { text: title }), closeBtn ]);

    const panel = el("div", { id: "ask-anna-panel" }, [ header, log, form ]);

    root.appendChild(toggle);
    root.appendChild(panel);
    document.body.appendChild(root);

    toggle.addEventListener("click", () => {
      panel.classList.toggle("open");
      if (panel.classList.contains("open")) input.focus();
    });
    closeBtn.addEventListener("click", () => panel.classList.remove("open"));

    form.addEventListener("submit", (event) => {
      event.preventDefault();
      const question = input.value.trim();
      if (!question || submit.disabled) return;

      appendQuestion(log, question);
      input.value = "";
      submit.disabled = true;

      askQuestion(question)
        .then((body) => appendAnswer(log, body.answer, body.sources))
        .catch((error: Error) => appendError(log, error.message || "Qualcosa e' andato storto. Riprova tra poco."))
        .finally(() => {
          submit.disabled = false;
        });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
