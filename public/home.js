"use strict";
/*!
 * Ask Anna homepage chat (app/views/pages/home.html.erb).
 *
 * Source of truth for public/home.js; compiled via `npm run build` (see
 * package.json). Don't hand-edit the compiled output.
 */
(function () {
    "use strict";
    const log = document.getElementById("ask-anna-log");
    const form = document.getElementById("ask-anna-form");
    const input = document.getElementById("ask-anna-input");
    const submit = document.getElementById("ask-anna-submit");
    if (!log || !form || !input || !submit)
        return;
    function el(tag, className, text) {
        const node = document.createElement(tag);
        node.className = className;
        if (text !== undefined)
            node.textContent = text;
        return node;
    }
    function appendQuestion(question) {
        log.appendChild(el("p", "max-w-[85%] self-end rounded-lg bg-indigo-600 px-3 py-2 text-sm text-white", question));
        log.scrollTop = log.scrollHeight;
    }
    function appendAnswer(text, sources) {
        const wrapper = el("div", "max-w-[85%] self-start rounded-lg bg-indigo-50 px-3 py-2 text-sm text-indigo-950");
        wrapper.appendChild(el("p", "", text));
        if (sources.length > 0) {
            const sourcesEl = el("div", "mt-1.5 flex flex-col gap-0.5");
            sources.forEach((url) => {
                const link = el("a", "break-all text-xs text-indigo-600 hover:underline", url);
                link.setAttribute("href", url);
                link.setAttribute("target", "_blank");
                link.setAttribute("rel", "noopener noreferrer");
                sourcesEl.appendChild(link);
            });
            wrapper.appendChild(sourcesEl);
        }
        log.appendChild(wrapper);
        log.scrollTop = log.scrollHeight;
    }
    function appendError(text) {
        log.appendChild(el("p", "max-w-[85%] self-start rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700", text));
        log.scrollTop = log.scrollHeight;
    }
    function appendSpinner() {
        const bubble = el("p", "max-w-[85%] self-start rounded-lg bg-indigo-50 px-3 py-2 text-sm text-indigo-400 animate-pulse", "Thinking…");
        log.appendChild(bubble);
        log.scrollTop = log.scrollHeight;
        return bubble;
    }
    async function askQuestion(question) {
        const response = await fetch("/ask", {
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
    function submitQuestion(question) {
        if (!question || submit.disabled)
            return;
        appendQuestion(question);
        input.value = "";
        submit.disabled = true;
        const spinner = appendSpinner();
        askQuestion(question)
            .then((body) => {
            spinner.remove();
            appendAnswer(body.answer, body.sources);
        })
            .catch((error) => {
            spinner.remove();
            appendError(error.message || "Something went wrong. Please try again shortly.");
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
    document.querySelectorAll("[data-suggested-question]").forEach((button) => {
        button.addEventListener("click", () => {
            submitQuestion(button.dataset.suggestedQuestion ?? "");
        });
    });
})();
