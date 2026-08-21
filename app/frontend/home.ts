/*!
 * Ask Anna homepage chat (app/views/pages/home.html.erb).
 *
 * Source of truth for public/home.js; compiled via `npm run build` (see
 * package.json). Don't hand-edit the compiled output.
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

  const log = document.getElementById("ask-anna-log");
  const form = document.getElementById("ask-anna-form") as HTMLFormElement | null;
  const input = document.getElementById("ask-anna-input") as HTMLTextAreaElement | null;
  const submit = document.getElementById("ask-anna-submit") as HTMLButtonElement | null;

  if (!log || !form || !input || !submit) return;

  function el<K extends keyof HTMLElementTagNameMap>(
    tag: K,
    className: string,
    text?: string
  ): HTMLElementTagNameMap[K] {
    const node = document.createElement(tag);
    node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function appendQuestion(question: string): void {
    log!.appendChild(el("p", "max-w-[85%] self-end rounded-lg bg-gray-900 px-3 py-2 text-sm text-white", question));
    log!.scrollTop = log!.scrollHeight;
  }

  function appendAnswer(text: string, sources: string[]): void {
    const wrapper = el("div", "max-w-[85%] self-start rounded-lg bg-gray-100 px-3 py-2 text-sm text-gray-700");
    wrapper.appendChild(el("p", "", text));

    if (sources.length > 0) {
      const sourcesEl = el("div", "mt-1.5 flex flex-col gap-0.5");
      sources.forEach((url) => {
        const link = el("a", "break-all text-xs text-blue-600 hover:underline", url);
        link.setAttribute("href", url);
        link.setAttribute("target", "_blank");
        link.setAttribute("rel", "noopener noreferrer");
        sourcesEl.appendChild(link);
      });
      wrapper.appendChild(sourcesEl);
    }

    log!.appendChild(wrapper);
    log!.scrollTop = log!.scrollHeight;
  }

  function appendError(text: string): void {
    log!.appendChild(el("p", "max-w-[85%] self-start rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700", text));
    log!.scrollTop = log!.scrollHeight;
  }

  function appendSpinner(): HTMLElement {
    const bubble = el("p", "max-w-[85%] self-start rounded-lg bg-gray-100 px-3 py-2 text-sm text-gray-500 animate-pulse", "Thinking…");
    log!.appendChild(bubble);
    log!.scrollTop = log!.scrollHeight;
    return bubble;
  }

  async function askQuestion(question: string): Promise<AskResponse> {
    const response = await fetch("/ask", {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({ question })
    });

    const body = (await response.json()) as AskResponse | AskErrorResponse;

    if (!response.ok) {
      throw new Error("error" in body ? body.error : "Something went wrong.");
    }

    return body as AskResponse;
  }

  input.addEventListener("keydown", (event) => {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      form!.requestSubmit();
    }
  });

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const question = input!.value.trim();
    if (!question || submit!.disabled) return;

    appendQuestion(question);
    input!.value = "";
    submit!.disabled = true;
    const spinner = appendSpinner();

    askQuestion(question)
      .then((body) => {
        spinner.remove();
        appendAnswer(body.answer, body.sources);
      })
      .catch((error: Error) => {
        spinner.remove();
        appendError(error.message || "Something went wrong. Please try again shortly.");
      })
      .finally(() => {
        submit!.disabled = false;
      });
  });
})();
