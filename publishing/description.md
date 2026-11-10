<!-- Project description for CurseForge and Wago (both accept Markdown). Keep in sync with README.md. -->

**Kibble** puts one movable button on your screen for your hunter pet: feed it, revive it, call it back.
Built for **WoW Forever**.

## What it does

- **One-click feeding.** Left-click (or press a key) and Kibble feeds your pet the best food in your bags.
  By default it saves your good food: it uses the cheapest food that still fully feeds the pet. Other modes:
  smallest stack first, or always the best food. You can ignore foods you never want used.
- **Pet care.** With no living pet the same button revives a dead pet or calls a missing one, and
  **Ctrl-click mends**. Works in combat.
- **Vendor restock.** At a vendor that sells food your pet eats, a *Buy N pet food* button appears on the
  tab row and tops you up to 20 / 40 / 80 / 120. Nothing is bought until you click. It matches the stock
  vendor window, and EllesmereUI's when that is installed.
- **Mood ring.** Green, yellow or red around the button, pulsing when the pet isn't happy, plus a countdown
  while the pet is eating.
- **Warnings.** On-screen message and chat line when you run out of food, optionally when you're running low,
  and an optional sound (off by default).
- **Everything is a right-click away.** Alerts, size and opacity, lock position, food choice, visibility.
  There's also an options panel (Options > AddOns > Kibble), a draggable minimap button and an
  addon-compartment entry.

## Using it

| Action | What it does |
| --- | --- |
| Left-click / key binding | Feed the pet (or revive / call it) |
| Ctrl-click | Mend Pet |
| Right-click | Settings menu |
| Shift-drag | Move the button |
| `/kibble` | Pet mood and the food Kibble would pick |
| `/kibble config` | Open the settings menu |
| `/kibble reset` | Reset the button position |

Bind a key under **Options > Key Bindings > AddOns > Kibble**.

## Notes

- Hunters only; the addon does nothing on other classes.
- Feeding is a protected action, so it only happens when you click or press the key.
- Source, issues and changelog: https://github.com/PacifistPanda/Kibble
