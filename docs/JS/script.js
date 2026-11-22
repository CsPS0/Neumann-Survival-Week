"use strict"

// Language (EN / HU, remembered in this browser) and the game's version, read from the game's own code on GitHub
// (ROBLOX-GAME/src/shared/Config.luau, Config.VERSION) so the page never shows a stale one.

const VERSION_URL = "https://raw.githubusercontent.com/CsPS0/Neumann-Survival-Week/main/ROBLOX-GAME/src/shared/Config.luau";

function savedLanguage() {
    try {
        const saved = localStorage.getItem("lang");
        if (saved === "en" || saved === "hu") {
            return saved;
        }
    } catch (e) {
        // Storage blocked: fall through to the browser's language.
    }
    return (navigator.language || "en").toLowerCase().startsWith("hu") ? "hu" : "en";
}

function applyLanguage(lang) {
    const strings = translations[lang] || translations.en;
    document.documentElement.lang = lang;
    document.querySelectorAll("[data-translate]").forEach((element) => {
        const text = strings[element.dataset.translate];
        if (text) {
            element.innerHTML = text;
        }
    });
    document.querySelectorAll(".lang button").forEach((button) => {
        button.setAttribute("aria-pressed", String(button.dataset.lang === lang));
    });
    try {
        localStorage.setItem("lang", lang);
    } catch (e) {
        // Not remembered: fine.
    }
}

async function showVersion() {
    const label = document.getElementById("version");
    try {
        const response = await fetch(VERSION_URL, { cache: "no-store" });
        if (!response.ok) {
            return;
        }
        const match = (await response.text()).match(/Config\.VERSION\s*=\s*"([^"]+)"/);
        if (match) {
            label.textContent = match[1];
        }
    } catch (e) {
        // Offline or blocked: the version written in the page stays.
    }
}

document.addEventListener("DOMContentLoaded", () => {
    document.querySelectorAll(".lang button").forEach((button) => {
        button.addEventListener("click", () => applyLanguage(button.dataset.lang));
    });
    applyLanguage(savedLanguage());
    showVersion();
});
