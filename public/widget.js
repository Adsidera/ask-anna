"use strict";
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
 * from the same host it can be omitted. widget.css is loaded from the
 * same directory as this script (it deliberately skips Tailwind's
 * preflight reset, see app/frontend/styles/widget.css, so it's safe to
 * load on an arbitrary third-party page).
 *
 * Source of truth is this file; it's compiled to public/widget.js via
 * `npm run build` (see package.json). Don't hand-edit the compiled output.
 */
(function () {
    "use strict";
    const currentScript = document.currentScript;
    const apiBase = currentScript?.dataset.apiBase ?? "";
    const title = currentScript?.dataset.title ?? "Ask Anna";
    const askUrl = apiBase.replace(/\/$/, "") + "/ask";
    const suggestedQuestionsUrl = apiBase.replace(/\/$/, "") + "/suggested_questions";
    const cssUrl = currentScript ? new URL("widget.css", currentScript.src).href : "widget.css";
    function el(tag, attrs, children) {
        const node = document.createElement(tag);
        Object.entries(attrs ?? {}).forEach(([key, value]) => {
            if (key === "text") {
                node.textContent = value;
            }
            else if (key === "class") {
                node.setAttribute("class", value);
            }
            else {
                node.setAttribute(key, value);
            }
        });
        (children ?? []).forEach((child) => node.appendChild(child));
        return node;
    }
    function appendQuestion(log, question) {
        log.appendChild(el("p", { class: "max-w-[85%] self-end rounded-lg bg-gray-900 px-3 py-2 text-sm font-medium text-white", text: question }));
        log.scrollTop = log.scrollHeight;
    }
    function appendAnswer(log, text, sources) {
        const wrapper = el("div", { class: "max-w-[85%] self-start rounded-lg bg-gray-100 px-3 py-2 text-sm text-gray-700" });
        wrapper.appendChild(el("p", { text }));
        if (sources.length > 0) {
            const sourcesEl = el("div", { class: "mt-1.5 flex flex-col gap-0.5" });
            sources.forEach((url) => {
                sourcesEl.appendChild(el("a", {
                    href: url,
                    target: "_blank",
                    rel: "noopener noreferrer",
                    class: "break-all text-xs text-blue-600 hover:underline",
                    text: url
                }));
            });
            wrapper.appendChild(sourcesEl);
        }
        log.appendChild(wrapper);
        log.scrollTop = log.scrollHeight;
    }
    function appendError(log, text) {
        log.appendChild(el("p", { class: "max-w-[85%] self-start rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700", text }));
        log.scrollTop = log.scrollHeight;
    }
    function appendSpinner(log) {
        const bubble = el("p", {
            class: "max-w-[85%] self-start rounded-lg bg-gray-100 px-3 py-2 text-sm text-gray-500 animate-pulse",
            text: "Thinking…"
        });
        log.appendChild(bubble);
        log.scrollTop = log.scrollHeight;
        return bubble;
    }
    async function askQuestion(question) {
        const response = await fetch(askUrl, {
            method: "POST",
            headers: { "Content-Type": "application/json", Accept: "application/json" },
            body: JSON.stringify({ question })
        });
        const body = (await response.json());
        if (!response.ok) {
            throw new Error("error" in body ? body.error : "Something went wrong.");
        }
        return body;
    }
    async function fetchSuggestedQuestions() {
        const response = await fetch(suggestedQuestionsUrl, { headers: { Accept: "application/json" } });
        if (!response.ok)
            return [];
        const body = (await response.json());
        return body.questions ?? [];
    }
    function init() {
        document.head.appendChild(el("link", { rel: "stylesheet", href: cssUrl }));
        const root = el("div", { id: "ask-anna-widget", class: "fixed right-5 bottom-5 z-[2147483000] font-sans" });
        const toggle = el("button", {
            type: "button",
            "aria-label": title,
            class: "flex h-14 w-14 items-center justify-center rounded-full border-none bg-gray-900 text-xl text-white shadow-lg shadow-black/25 hover:bg-gray-700",
            text: "?"
        });
        const log = el("div", { class: "flex flex-1 flex-col gap-2.5 overflow-y-auto p-3.5 text-sm text-gray-900" }, [
            el("p", {
                class: "max-w-[85%] self-start rounded-lg bg-gray-100 px-3 py-2 text-gray-700",
                text: "Ask me anything about Anna's professional experience."
            })
        ]);
        const input = el("textarea", {
            placeholder: "Ask a question...",
            rows: "1",
            class: "h-10 flex-1 resize-none rounded-lg border border-gray-300 p-2 font-sans text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-gray-800"
        });
        const submit = el("button", {
            type: "submit",
            class: "rounded-lg border-none bg-gray-900 px-3.5 text-sm text-white hover:bg-gray-700 disabled:cursor-default disabled:opacity-50",
            text: "Send"
        });
        const form = el("form", { class: "flex gap-1.5 border-t border-gray-200 p-2.5" }, [input, submit]);
        const suggestions = el("div", { class: "flex flex-wrap gap-1.5 border-t border-gray-200 px-2.5 py-2" });
        const closeBtn = el("button", {
            type: "button",
            "aria-label": "Close",
            class: "border-none bg-transparent text-lg leading-none text-white",
            text: "✕"
        });
        const header = el("div", { class: "flex items-center justify-between bg-gray-900 px-4 py-3.5 font-semibold text-white" }, [el("span", { text: title }), closeBtn]);
        const panel = el("div", {
            id: "ask-anna-panel",
            class: "fixed right-5 bottom-[88px] hidden h-[460px] max-h-[calc(100vh-120px)] w-[340px] max-w-[calc(100vw-40px)] flex-col overflow-hidden rounded-xl bg-white shadow-2xl shadow-black/25"
        }, [header, log, suggestions, form]);
        root.appendChild(toggle);
        root.appendChild(panel);
        document.body.appendChild(root);
        toggle.addEventListener("click", () => {
            const isOpen = panel.classList.toggle("flex");
            panel.classList.toggle("hidden", !isOpen);
            if (isOpen)
                input.focus();
        });
        closeBtn.addEventListener("click", () => {
            panel.classList.add("hidden");
            panel.classList.remove("flex");
        });
        function submitQuestion(question) {
            if (!question || submit.disabled)
                return;
            appendQuestion(log, question);
            input.value = "";
            submit.disabled = true;
            const spinner = appendSpinner(log);
            askQuestion(question)
                .then((body) => {
                spinner.remove();
                appendAnswer(log, body.answer, body.sources);
            })
                .catch((error) => {
                spinner.remove();
                appendError(log, error.message || "Something went wrong. Please try again shortly.");
            })
                .finally(() => {
                submit.disabled = false;
            });
        }
        input.addEventListener("keydown", (event) => {
            if (event.key === "Enter" && !event.shiftKey) {
                event.preventDefault();
                form.requestSubmit();
            }
        });
        form.addEventListener("submit", (event) => {
            event.preventDefault();
            submitQuestion(input.value.trim());
        });
        fetchSuggestedQuestions().then((questions) => {
            questions.forEach((question) => {
                const chip = el("button", {
                    type: "button",
                    class: "rounded-full border border-gray-300 bg-white px-2.5 py-1 text-xs text-gray-700 hover:bg-gray-100",
                    text: question
                });
                chip.addEventListener("click", () => submitQuestion(question));
                suggestions.appendChild(chip);
            });
            if (questions.length === 0)
                suggestions.remove();
        }).catch(() => suggestions.remove());
    }
    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", init);
    }
    else {
        init();
    }
})();
