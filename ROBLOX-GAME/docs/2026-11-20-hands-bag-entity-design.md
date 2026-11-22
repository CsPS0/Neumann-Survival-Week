# Hands, phone, backpack, entity and school look: design

Date: 2026-11-20. Status: draft for approval (builder check done).

## Intent

The Roblox port should feel closer to the Godot game and scarier to play with friends:

1. **The phone is the light:** held in a visible hand, its flashlight animates (sway, bob, the thumb click, the
   camera flash). There is no separate torch.
2. **The phone** is used like a phone in GTA: one hand (small phone in view, arrow
   keys, Space to open, Backspace to go back) or two hands (full screen, mouse cursor).
3. **A real backpack:** you carry items in your hand, two pockets and a bag. To get something out of the bag you
   drop the bag, open it and take the item out. Small things fit in pockets.
4. **A scarier entity** with gore, that secretly wears pieces of the possessed teacher, so sharp players can spot who
   it is.
5. **The school looks like the Godot game's photos** (terrazzo floor, beige walls, grey wood ceiling, white doors,
   green boards, fluorescent lamps).

## Decided with the user

- Gore level: **Moderate (13+)**. Wounds, exposed flesh and ribs, bleeding eyes, light realistic blood. No pools of
  blood, no gushing. The game's maturity questionnaire answers: realistic blood, light; fear moderate.
- Co-op: **each player has their own hand, pockets and bag; anyone can open a dropped bag.** Sharing is physical:
  drop your bag, a friend opens it and takes what they need. This replaces the shared team inventory.
- Textures: **imitated with Roblox built-in materials and colours**, nothing uploaded to the user's account.
- Using an item (fuse box, cabinet, safe, altar, red door): **the item must be in your hand or a pocket.** Items in
  the bag must be taken out first.

## Goals, non-goals, anti-goals

- Goals: the five points of the intent, working solo and in co-op, on keyboard and mouse and on phones.
- Non-goals: drag and drop in the bag panel (click to move is enough); item crafting; the Godot phone apps beyond the
  ones listed here (no e-Kréten, mecha, finds); uploaded images or meshes; changing the Hide and Seek or Social
  Deduction rules.
- Anti-goals (a failure even if it works):
  - a soft-lock because a needed item is stuck in a bag nobody can reach;
  - the phone eating movement keys so you cannot walk while it is up;
  - viewmodels that clip through walls or show in other players' view;
  - gore beyond the 13+ label (that would lock out the user's school friends);
  - a frame-rate drop (the user fought hard for 60 FPS; budget below).

## Approaches considered

- **Viewmodel:** (chosen) local 3D parts in the camera, animated every frame, like `phone_viewmodel.gd`. A flat 2D phone picture was dropped: without uploaded images it would be boxes, and it cannot
  sway with the hand.
- **Phone screen:** (chosen) one UI tree that lives in a `SurfaceGui` on the 3D phone in one-hand mode and is moved
  into a full-screen `ScreenGui` in two-hand mode. Two separate UIs were dropped: twice the code for the same apps.
- **Inventory:** (chosen) server-authoritative, a pure shared `Inventory` module with Lune tests, a server service
  that owns everyone's inventory and the dropped bag models, and a client panel. A client-owned inventory was dropped:
  items gate the story and must not be faked.
- **Gore without images:** (chosen) geometry and colour (parts, `ParticleEmitter` drips with the default texture
  tinted dark red, small blood spots as flat parts). Images would look better but the user chose no uploads.

## Design

### 1. Hands and the phone flashlight (client, `Viewmodel.luau`)

**User decision (2026-11-20): there is no separate torch; the light is the phone's flashlight.** The phone is always
in the left hand; the right hand holds the hand-slot item (or is empty).

- A local `Model` in `workspace.CurrentCamera`: left forearm and hand holding the phone (body, screen face, a small
  flashlight lens on the back), right forearm and hand (with the held item). Every part: anchored,
  `CanCollide/CanQuery/CanTouch` false, `CastShadow` false. Only the local player sees it (it is under the camera,
  which does not replicate).
- **Lowered** (normal walking): the phone is held low and forward, back to the world, so the flashlight points ahead.
- Placed every frame (`RenderStepped`, after `CameraController`) at a fixed offset from the camera, plus:
  - **sway:** a spring follows the mouse delta (the hands lag behind the turn);
  - **bob:** a figure-eight from the walk speed, matching the camera bob phase;
  - **crouch / sprint:** sprint lowers and tilts the phone; crouch lowers both hands;
  - **click (F):** flashlight on or off: the thumb taps the phone side (0.1 s), the lens turns Neon on or off;
  - **camera flash (T):** a 0.15 s lift towards the target, the lens flares white (the stun rules stay as they are);
  - **wall push:** a short ray forward; within 0.6 m of a wall the hands pull back so they never clip.
- Hidden when: no character, state not `alive`, hidden in a locker, spectating. With `TorchAllowed` false (the Hide
  and Seek player seeker) the hands show without a phone.
- The light itself stays server-side (the existing `Torch` module's `SpotLight`), moved to the character's left hand
  so other players see it come from the phone. The battery is the phone battery: the flashlight drains it as before,
  at 0% the flashlight and the flash stop, **the screen keeps working** (agent's call: losing the map and tasks would
  be a soft-lock on Easy). The HUD bar reads "Phone battery".

### 2. Phone (client, `Phone.luau`; `StoryHud` keeps only the objective line and the Easy marker)

- **P** raises the phone to look at the screen, or lowers it again (0.25 s animation). **H** switches one hand / two
  hands while it is up. Phones (touch): a Phone button opens two-hand mode only.
- **One hand:** the 3D phone comes up in front of you, the screen is a `SurfaceGui` on it. Keys while it is up (bound
  with `ContextActionService:BindActionAtPriority` above the default controls, so they never move the character):
  Up/Down/Left/Right move the highlight, **Space** opens or selects (no jump while the phone is up), **Backspace**
  goes back; Backspace on the home screen lowers the phone. WASD, mouse look and Shift still work. The flashlight
  stays on if it was on (it shines from the back of the phone).
- **Two hands:** the phone fills the screen (9:16, full height) in a `ScreenGui` and the mouse is free (`Modal`). The
  held item is hidden while both hands are on the phone; the flashlight stays as it was. Click to open, Backspace or a
  Back button to go back.
- **Apps** (home screen: a 2-column grid of tiles):
  - **Map:** the floor plan drawn from `FloorData` room rectangles; Left/Right switch floor; your marker shows outside
    the story and on Easy in the story.
  - **Tasks:** the objective, your skips, the team quiz score, the altar progress at night.
  - **Timetable:** as on the current phone.
  - **Clues:** the team's clue list (clues stay team-shared on the phone).
  - **Team:** who is alive, downed or out.
  - Outside the story only Map shows.
- The status bar shows the clock and the phone battery.
- The current `StoryHud` phone panel is removed; `CampaignState` feeds the apps.

### 3. Hand, pockets and bag

- **Pure module `src/shared/Inventory.luau`** (Lune tests):
  - slots: `hand` (1), `pocketL` (1), `pocketR` (1), `bag` (8);
  - items: `key` storage key (small, 0.1 kg), `vial` holy water (small, 1.0), `salt` (big, 1.2), `fuse` (big, 0.8),
    `bell` silver bell (big, 1.5), `papers` (small, 0.1; one stack of read papers, see below), `battery` (small, 0.2);
  - big items never go in a pocket;
  - `add(inv, id, data?)`: the hand if empty, else a free pocket if small, else the bag if worn and not full; returns
    the slot or nil ("No room");
  - `reachable(inv, id)`: hand or pocket only; `take(inv, id)` removes from there;
  - `move(inv, fromSlot, toSlot, otherBag?)`: swaps or moves, respecting the pocket rule;
  - `speed(inv)`: 1 with no bag on; with the bag on, 1 - 0.03 x (3 kg empty bag + items), never below 0.7 (Godot
    numbers).
- **Papers:** every clue and safe-code note you pick up adds its text to your single `papers` item (one slot however
  many). The bag panel's Read button shows them. Clue texts also go to the team's phone list as now; **safe-code notes
  only live on the paper**, so whoever has the papers knows the code (they can read it out to the team or hand the
  papers over). This gives the bag a job.
- **Batteries** (2-4 per run in empty rooms): from the hand or a pocket, the key **U** (or the bag panel's Use button)
  adds 35% phone battery (a power bank: the item's name is "Power bank").
- **Server `src/server/Inventories.luau`:**
  - one inventory per player in the story, reset per run; sends the owner a snapshot (`Inventory` remote) on change;
  - **B** (remote `BagAction {op = "drop"}`): drops your worn bag in front of you as a `Bag` model in
    `workspace.Campaign.Bags` with two prompts: **E "Open bag"** (anyone alive within reach) and **B "Put on"** (only
    the owner; anyone alive if the owner is out or gone). Your speed goes back to normal while it is off.
  - **Bag panel** (`BagUi.luau`, mouse free): left, the open bag's 8 slots ("Bag of <name>"); right, your hand and
    pockets. Click an item, then click where it goes. Buttons: **Read** (papers), **Use** (battery), **Drop on the
    floor** (the item becomes a pickup there), **Close**. The server checks every move: the opener is alive and within
    12 studs of the bag, the bag is on the ground, the pocket rule. Two players can have the same bag open; the server
    is the truth and re-sends the bag to everyone looking at it.
  - **Picking up** a world item (salt, fuse, battery, a dropped item): `add`; no room = "No room. Drop your bag and
    make space." and the item stays.
  - **Out, left, or the run ends:** an out or leaving player's hand and pocket items go into their bag (worn or
    dropped); what does not fit drops as pickups beside it; a worn bag is dropped where they stand. Nothing is lost,
    so no soft-lock. An Easy solo "wake at the entrance" keeps everything.
- **Hotbar** (bottom centre, story only): Hand, L, R and BAG (worn / dropped / weight), the hand item's name for a
  moment when it changes.
- **Story changes:** the porter gives the key into your inventory; the red door, the fuse box, the cabinet, the safe
  and the altar use `reachable`/`take` of the player who presses E; the cabinet and the safe `add` the vial and the
  bell to that player (no room = message, try again). The altar keeps its placed items for the whole team as now.
  `Quest.items` and the phone's team item list go away.

### 4. Entity

- **`EntityModel.build(markId?)`**, new look (same root, size and joints as now, so `EntityAI` is untouched):
  - grey-pale skin with dark red open wounds (inset parts) on the arms, neck and face;
  - a torn torso: the black cloth replaced by shredded strips in the possessed teacher's **jacket colour** and
    **trouser colour** (`Teachers` colours, moved to `CampaignData.LOOKS`), with an opened chest showing pale ribs
    over dark red;
  - an unhinged jaw with teeth, black eye sockets with the red glow, two blood streaks down the cheeks;
  - long fingers with dark red tips;
  - a `ParticleEmitter` dripping dark red drops from the chest and hands (low rate);
  - while it moves, a small dark red spot (flat part) on the floor every 2 s, faded and removed after 20 s, at most
    25 at a time.
  - **The teacher's mark**, matching their "item" clues (`CampaignData.ENTITY_MARKS`): Kárpáti a brass key on a
    lanyard; Szentgyörgyi a charm bracelet with a silver bell; Halmos a spool of fuse wire on the belt; Vörös a black
    feather in the hair; Pásztor a red ribbon round the neck; Ónodi a USB stick on a lanyard; Fekete network cable
    wound round one arm; Lázár a crest ring and a keyring.
  - Hide and Seek and Social Deduction (no culprit): the generic torn black clothes, no mark.
- **Afternoon glimpses** (story, after the explosion, before 18:00): twice per run at random times between 14:00 and
  17:30 (game clock). Pick a random alive player; find a spot 10-30 m away on their floor, from the patrol points,
  with a clear ray to them; show a frozen copy of the entity (with the mark) there facing them, a sting, gone after
  2.5 s or when they come within 8 m. Harmless. On every difficulty (it is a clue).
- Keep the existing scare rule: no glimpse while a vote or quiz panel is open for that player.

### 5. School look (`SchoolBuilder.luau`, `STYLE`)

- Floors: terrazzo: `Granite`, light grey (150, 146, 138).
- Walls: two bands like the Godot shader: the lower 1.6 m `CeramicTiles` beige (196, 168, 128), a thin dark trim
  line, plaster `Plaster` off-white (234, 231, 224) above. Built as a thin lower facing on each room's inner wall
  faces, not by doubling every wall part, so the part count grows by at most ~35%.
- Ceilings: `WoodPlanks`, grey-brown (112, 98, 88).
- Doors: off-white `SmoothPlastic` (232, 230, 224), a brass handle (`Metal`, (180, 140, 70)) and a blue room sign
  with the room label in white (`SurfaceGui`), like the photo.
- Boards: a green `Slate` board (40, 82, 62) on the front wall of every `normal` classroom, with chalk-white text of
  the room's subject or a few chalk lines (`SurfaceGui`).
- Lamps: the panel becomes four Neon tubes under a thin metal grille (the existing `SpotLight` stays).

### Performance budget

- Viewmodel and phone: under 0.3 ms a frame (about 15 parts, springs, one ray).
- School: total parts at most 3,000 (now 2,111). Re-measure FPS in Studio (MicroProfiler header) after the build:
  must stay at 60 on the user's PC.
- Entity: gore parts welded, no extra physics; blood spots capped at 25.

## Calls made after the builder check (agent's calls)

- **Seeing what you carry:** **Tab** opens a small "Carrying" panel (mouse free): your hand and pockets, plus the
  worn bag's contents greyed out (you cannot take them while it is on your back). Read works there for papers in
  your hand or a pocket. Papers in the worn bag cannot be read until you drop the bag and open it.
- **Other modes:** outside the story the phone has **Map only** (no Team list: it would reveal Social Deduction
  kills and break the tags). The new gory look is used everywhere (it is only looks), but the **blood drips and the
  floor trail are story-only**, so a Hide and Seek player seeker leaves no trail. No mode rules change.
- **The hand item:** shown as a simple model (box or cylinder in the item's colour) in the **right hand** (the phone
  is in the left); two-hand phone mode puts it out of view (it stays in the hand slot). Not shown to other players.
- **Papers with no room:** a clue paper always counts for the team (its text joins the phone list) even when you
  have no room; only the paper item needs a slot. If you already carry papers, a new paper joins the stack and needs
  no slot. A safe-code note with no room stays on its table ("No room for the note"). Moving one papers item onto
  another merges them. Banners: a clue still shows its text to everyone (team clues); a safe-code note only says
  "<name> found a note", the code stays on the paper.
- **Glimpses:** a server model everyone can see; the chosen player only decides where it appears.
- **Part count:** 60 FPS on the user's PC is the real limit; 3,000 parts is a target, not a wall. If the build goes
  over and FPS drops, the lamp grilles go first, then two tubes per lamp instead of four.

## Left to the builder

- Exact offsets, spring constants and colours (tune by looking in Studio).
- Map drawing details (room colours by type, labels on bigger rooms).
- Where batteries spawn.
- The board text per room.
- Touch layout of the hotbar and the Phone and Bag buttons.

## Testing

- Lune: `Inventory` (add order, pocket rule, bag full, reachable/take, move and swap, speed, papers stacking), and
  the entity mark table covering all 8 suspects.
- Studio (MCP scripted runs, as for the campaign): the full night quest with items in hand/pockets; a bag dropped
  and opened by the owner; the "out" spill; phone one-hand key navigation (arrow keys do not move the character,
  Space does not jump) and two-hand mouse; flashlight click and camera flash animations visible (screenshots); a glimpse fires
  in the afternoon; FPS check.
- Multiplayer (bag sharing, two players in one bag) goes on the README checklist.
