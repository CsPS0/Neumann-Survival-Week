"use strict"

const translations = {
    en: {
        title: "NJSZKI IKT RPG Game - IKT: Survival Week",
        subtitle: "An ASCII art RPG adventure.",
        features_title: "Features",
        features_1_title: "Quest-based Gameplay",
        features_1_text: "Engage in a variety of quests and make choices that matter.",
        features_2_title: "ASCII Art Graphics",
        features_2_text: "A unique retro aesthetic made entirely of text characters.",
        features_3_title: "Interactive Dialog",
        features_3_text: "Talk to NPCs and uncover the secrets of the school.",
        story_title: "Story",
        story_text: "You are a new student at the Neumann János Vocational School of Informatics, and you have to survive for a week. You will meet different NPCs, and you can get different quests from them.",
        about_title: "About the Game",
        about_1: "The game is based on different quests where the player can choose between options.",
        about_2: "Easter eggs reacting to certain steps will also be hidden.",
        about_3: "Animations enhance the experience.",
        about_4: "Detailed main menu and submenus for easier navigation.",
        about_5: "The player's answers are stored until the game is closed.",
        controls_title: "Controls",
        controls_1: "Movement on the map, selection in the menu (W/S: up/down, A/D: switch)",
        controls_2: "Select in menu",
        controls_3: "Back to menu or exit",
        controls_4: "Interact with NPCs",
        controls_5: "Inventory",
        gallery_title: "Gallery",
        documentation_title: "Code Documentation",
        documentation_text: "The project's documentation is available in the main README.md file.",
        team_title: "The Team",
        documents_title: "Documents",
        documents_license: "License"
    },
    hu: {
        title: "NJSZKI IKT RPG Játék - IKT: Túlélő Hét",
        subtitle: "Egy ASCII art RPG kaland.",
        features_title: "Jellemzők",
        features_1_title: "Küldetés alapú játékmenet",
        features_1_text: "Vegyen részt különféle küldetésekben, és hozzon fontos döntéseket.",
        features_2_title: "ASCII Art Grafika",
        features_2_text: "Egyedi retro esztétika, teljes egészében szöveges karakterekből.",
        features_3_title: "Interaktív Párbeszéd",
        features_3_text: "Beszéljen az NPC-kkel, és fedezze fel az iskola titkait.",
        story_title: "Történet",
        story_text: "Új diák vagy a Neumann János Számítástechnikai Szakközépiskolában, és egy hetet kell túlélned. Különböző NPC-kkel találkozol, és különböző küldetéseket kaphatsz tőlük.",
        about_title: "A Játékról",
        about_1: "A játék különböző küldetésekre épül, ahol a játékos választhat a lehetőségek között.",
        about_2: "Bizonyos lépésekre reagáló easter egg-ek is lesznek elrejtve.",
        about_3: "Animációk fokozzák az élményt.",
        about_4: "Részletes főmenü és almenük a könnyebb navigációhoz.",
        about_5: "A játékos válaszai eltárolásra kerülnek a játék bezárásáig.",
        controls_title: "Irányítás",
        controls_1: "Mozgás a pályán, menüben választás (W/S: fel/le, A/D: váltás)",
        controls_2: "Menüben választás",
        controls_3: "Vissza a menübe vagy kilépés",
        controls_4: "Interakció NPC-kkel",
        controls_5: "Leltár",
        gallery_title: "Galéria",
        documentation_title: "Kód Dokumentáció",
        documentation_text: "A projekt dokumentációja a fő README.md fájlban található.",
        team_title: "A Csapat",
        documents_title: "Dokumentumok",
        documents_license: "Licenc"
    }
};

function applyTranslations() {
    const lang = document.getElementById('language-selector').value;
    document.querySelectorAll('[data-translate]').forEach(element => {
        const key = element.dataset.translate;
        if (translations[lang] && translations[lang][key]) {
            element.innerHTML = translations[lang][key];
        }
    });
}

document.addEventListener('DOMContentLoaded', () => {
    const langSelector = document.getElementById('language-selector');
    langSelector.addEventListener('change', applyTranslations);
    applyTranslations(); // Apply translations on initial load
});