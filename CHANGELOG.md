# Changelog

## 1.4.0 - 2026-11-10

- Profiles: each character uses a named profile; new characters start on *Default*. Right-click >
  Profiles to switch, create, copy, rename, reset or delete them. Your current settings become the
  *Default* profile automatically.
- Export / import: share a profile as a text string (`/kibble export`, `/kibble import`, or the Profiles
  menu). Imports are validated: only known settings with valid values are accepted, anything else is
  skipped and counted.
- Profile commands: `/kibble profile` lists them, `/kibble profile <name>` switches.
- A profile holds all settings and the ignore list. The button position and the minimap button angle stay
  per account.

## 1.3.1 - 2026-11-10

- The vendor restock button now matches the vendor window. With EllesmereUI it is styled as one of the
  window's own tabs (through EllesmereUI's skinning API); in the stock UI it stays a normal button.
- It sits on the tab row, right of Merchant / Buyback, and fills up to the window's edge. The label is
  now *Buy N pet food*.
- Fixed: the restock button could stay hidden after summoning your pet while a vendor was open.
- Fixed: restock picks among the foods you can afford instead of failing when the best-ranked food is
  too expensive; with no gold it shows a greyed *Can't afford pet food*.
- EllesmereUI also skins the button and checkboxes on the options panel.
- New `/kibble vendor` diagnostic: explains why the restock button is or isn't showing.

## 1.3.0 - 2026-11-10

- Pet care: with no living pet the button revives a dead pet or calls a missing one; Ctrl-click mends.
  Works in combat. Toggle under right-click > Visibility.
- Vendor restock: a button under the vendor window buys up to a target (20 / 40 / 80 / 120) of the food
  Kibble would pick. Nothing is bought until you click; respects gold, bag space and the ignore list.
- Options panel (Options > AddOns > Kibble), a draggable minimap button and an addon-compartment entry.

## 1.2.0 - 2026-11-10

- Low-food warning at 5, 10 or 20 left (off by default).
- "Smallest stack first" food mode.
- Feeding countdown on the button while the pet eats (follows the Feed Pet buff).
- Alert sound picker with preview. Sound alerts are now opt-in and default to off; if you had sounds on
  from the 1.1.0 default they are switched off once.
- `/kibble buffs` diagnostic.

## 1.1.0 - 2026-11-10

- First public release (formerly FeedMe): one-button hunter pet feeding for WoW Forever.
- Right-click settings menu: alerts, appearance, food choice and ignore list, visibility.
- Addon icon. Your FeedMe button position is migrated on first load.
