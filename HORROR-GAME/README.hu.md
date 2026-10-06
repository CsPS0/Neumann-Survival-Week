# The Empty School (Az Üres Iskola, HORROR-GAME)

Belső nézetes 3D horrorjáték a Neumann iskolában, Godot 4.7-tel készítve.

English: [README.md](README.md)

Öt nap a Neumannban. Valami nincs rendben az épületben. Járj be az órákra, figyeld a tanárokat, és derítsd ki, ki az, mielőtt ő talál meg téged.

Állapot: játszható demó. A "Not available in the demo." feliratú termek zárva maradnak.

## Indítás

1. Telepítsd a [Godot 4.7](https://godotengine.org/download)-et (standard változat, .NET nem kell).
2. Klónozd a repót.
3. A Godot Project Managerben válaszd az Import gombot, és jelöld ki a `HORROR-GAME/project.godot` fájlt.
4. Várd meg az első importálás végét, majd nyomd meg az F5-öt (Run Project).

Megjegyzések:
- Friss klónból is fut. A tanári névsor a `scripts/staff_placeholder.gd` fájlra esik vissza, amelyben csak kitalált nevek vannak.
- Windowson a megjelenítő Direct3D 12-t használ. Más rendszeren a Godot alapértelmezett meghajtóját.
- Az exportbeállítások és a buildek nincsenek a repóban (az `export_presets.cfg` és a `build/` gitignore-olt). Futtatható fájlhoz vagy APK-hoz hozz létre saját export presetet a Godotban.

## Irányítás

| Billentyű | Művelet |
|---|---|
| W, A, S, D | Mozgás |
| Shift | Futás (korlátozott állóképesség, megállva újratöltődik) |
| Egér | Körülnézés |
| F | Zseblámpa (korlátozott elem) |
| Q | Telefon |
| Tab | Következő telefonoldal: térkép, feladatok, nyomok, leletek, neu_mecha |
| Bal / jobb nyíl | Emelet váltása a telefon térképén |
| E | Interakció: ajtók, tárgyak, tanárok, szekrények |
| Szóköz | Lélegzet visszatartása, amíg szekrényben rejtőzöl |
| G | A lény megnevezése (a 4. naptól) |
| 1 - 4 | Párbeszéd válasz kiválasztása |
| Esc | Szünet menü |
| R | Újraindítás egy befejezés után |

## Az iskola

- Három emelet, kódból felépítve az alaprajzadatokból (`scripts/floor_data.gd`): folyosók, lépcsőházak, tantermek, géptermek, mosdók, az aula és a porta.
- A berendezés generált: padok, székek, táblák, gépek, szekrények és mosdófülkék.
- Hat fotótextúra (`textures/`) fedi a falakat, padlót, mennyezetet, ajtókat, lámpákat és a táblát. A többi anyag és az összes hang futásidőben készül.

## Az ötnapos kampány

- **1. és 3. nap között: tanítási napok.** A nap 06:00-kor indul. Csengő jelzi a 7 órát. Érj be időben a jó terembe, és válaszolj egy 3 kérdéses dolgozatra. 6 kihagyott óra után kicsapnak. Az utolsó csengő után a főbejáraton át hazamész, vagy maradsz, és vállalod a kockázatot a gondnok miatt.
- **4. és 5. nap: vadászat napok.** Nincs tanítás. Megnevezed a gyanúsított tanárt. Ha igazad van, a történet küldetései megnyílnak, és a lény vadászni kezd rád.
- **Nappal és éjszaka.** Alkonyatkor a lámpák villognak. Az éjszakák majdnem teljesen sötétek, ezért csak a zseblámpa megbízható fény.

### Órák és dolgozatok

Hét tantárgy (matematika, irodalom, programozás, fizika, történelem, angol, hálózatok), mindegyik saját teremmel, tanárral és kérdéssel. Az órarend minden tanítási napon változik. A dolgozatok eredménye beleszámít a legjobb befejezésbe.

### Nyomozás

Nyolc kitalált tanár egyike a lény, minden játékban véletlenszerűen. A tanárok beszélnek, ha megnyomod az E-t. Az iskolában elrejtett nyomok mind pontosan egy tanárra mutatnak, a tettes pedig napról napra több furcsa mondatot ejt el. Olvasd el a nyomokat a telefonodon, majd nyomd meg a G-t a vádhoz.

### Ördögűzés

Négy egymásra épülő feladat vezet a szertartáshoz az aula oltáránál:

1. Szerezd meg a raktárkulcsot a portán (kölcsönkérd vagy lopd el), nyisd ki a piros zárt termet, és vedd el a sót és a biztosítékot.
2. Tedd be a biztosítékot a biztosítékdobozba, hogy a laborszekrény áramot kapjon, szerezd meg a labor kulcsát a porta faláról, és vedd el a szenteltvizet.
3. Találd meg a négy rejtett cetlit, fejtsd meg a széf kódját, nyisd ki a régi széfet a második emeleten, és vedd ki az ezüstcsengőt.
4. Tedd az oltárra a sót, a szenteltvizet és a csengőt, majd élj túl a szertartást éjjel (40 másodperc).

Az 5. napon az oltár egyezséget is kínál a démonnal.

## Szereplők

- **A lény:** magas, sápadt alak világító szemekkel. Nappal tehetetlen, éjjel ébred. Navigációs hálón járőrözik minden emeleten, kivizsgálja a futás zaját, és ha meglát, üldöz. Egy szekrényben elbújva megszakítod a rálátását.
- **Tanárok:** napi rutint követnek, órán a termükben állnak, alkonyatkor elhagyják az épületet. Tanítási napokon háttértanárok töltik meg a folyosókat.
- **A gondnok:** tanítás után járőrözik. Ha elkap, kicsapnak.
- **Csoki:** a gondnok kutyája. Ugat, ha a lény vagy a gondnok közel van. Egy kutyakeksz után követ téged.
- **A portás:** a porta pultja mögött áll, kulcsot ad kölcsön, és ellenőrzi a diákigazolványt.
- **Diákok:** órán a tantermekben ülnek, szünetben a folyosókon járnak.

A repóban szereplő minden karakternév kitalált.

## Befejezések

| # | Befejezés | Hogyan |
|---|---|---|
| 1 | Elkapva | A lény elkap vadászat közben. |
| 2 | Kiűzve | Befejezed a szertartást. |
| 3 | Kicsapva | Túl sok kihagyott óra, a gondnok elkap, vagy a tanítási nap úgy zárul, hogy még bent vagy. |
| 4 | Kitűnő tanuló | Befejezed a szertartást legalább 80%-os dolgozateredménnyel és 9 nyommal. |
| 5 | Elszöktél | Az utolsó csengő előtt, vagy vadászat napon kimész a főbejáraton. |
| 6 | Paktum | Egyezséget kötsz az oltárnál. |
| 7 | Túlóra | Az 5. nap válasz nélkül ér véget. |
| 8 | Rossz ember | Rossz tanárt vádolsz. |

## Egyebek

- Eredmények és látott befejezések, a beállításokkal együtt a `user://profile.cfg` fájlban.
- Beállítások: hangerő, egérérzékenység, látómező, fényerő, könnyű térkép (a telefon térképén megmutatja a helyzeted) és ijesztő villanások.
- A napi neu_mecha hírfolyam a telefonon: minden nap egy bejegyzés elrejt egy mecha kaméleont az iskolában.
- Rejtett oldalak, titkok és kártyák (telefon, "Finds" oldal).

## Kísérleti funkciók

Ezek a funkciók megvannak a kódban, de korai állapotúak, és valódi eszközön még nem voltak tesztelve:

- **Érintéses irányítás (Android):** képernyőn megjelenő joystick, nézőterület és gombok az F, Q, E, Tab és Esc funkciókhoz. A mobil eszközök alacsonyabb renderelési skálát használnak.
- **Co-op (legfeljebb 4 játékos):** Host Co-op és Join Co-op a főmenüben, előszobával, jelzéssel (középső egérgomb) és közelségi hanggal. A csatlakozás jelenleg csak ugyanarra a gépre működik (127.0.0.1).
- **VR (OpenXR):** a játék VR-ra vált, ha van OpenXR futtatókörnyezet, különben normál módban fut.

## A kód felépítése

| Útvonal | Tartalom |
|---|---|
| `scenes/main.tscn` | Fő jelenet. A `scripts/main.gd` építi az iskolát, helyezi el a történet tárgyait, és futtatja a HUD-ot és a játékmenetet. |
| `scripts/campaign.gd` | Napok, csengők, órák, statisztikák, a tettes és a befejezések. |
| `scripts/quest.gd` | A négylépéses ördögűzés. |
| `scripts/player.gd` | Belső nézetes vezérlő, zseblámpa, telefon, interakció. |
| `scripts/horror_entity.gd` | A lény MI-je: tétlen, járőrözés, üldözés, támadás. |
| `scripts/teacher_npc.gd`, `staff_manager.gd`, `caretaker.gd`, `porter.gd`, `csoki.gd`, `crowd.gd` | NPC-k. |
| `scripts/lessons.gd`, `lesson_ui.gd`, `clues.gd`, `endings.gd` | Játékadatok és felületük. |
| `scripts/floor_data.gd`, `rooms.gd`, `furniture.gd`, `textures.gd`, `sound_bank.gd` | Világ, anyagok és generált hang. |
| `scripts/menu.gd`, `settings_ui.gd`, `profile.gd`, `achievements.gd` | Menük, beállítások és mentett profil. |
| `scripts/staff_source.gd` | Betölti a gitignore-olt `scripts/staff.gd` fájlt, ha létezik, különben a mellékelt helyettesítőt. |
| `scripts/net_session.gd`, `input_bridge.gd`, `touch_controls.gd`, `xr_manager.gd` | Co-op, érintés és VR. |
