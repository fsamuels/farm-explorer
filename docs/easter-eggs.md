# Easter eggs

A running list of hidden or off-menu things in the game: ones that already exist
(some by accident) and ones we plan to build. Keep the "found" list honest: only
list what has been seen working.

## Found (already in the game)

### Rainbow at night
- **How:** use the keyboard instead of the sky menu. Press **T** until it is night,
  then press **R** until the weather reaches the rainbow (it is second to last in
  the cycle, just before the aurora).
- **Why it works:** the sky menu (G) only offers a rainbow from dawn to sunset
  (`Weather.SPECIAL_TIMES`). The T and R keys don't check, so they can put the
  two together.
- **Status:** accidental, and now a keeper.

### Aurora in the daytime
- **How:** press **T** until it is day (or sunrise, sunset, or dawn), then press
  **R** until the weather reaches the aurora (the last one in the cycle).
- **Why it works:** same as above. The menu only offers the aurora at dusk and at
  night, and the keys don't check.
- **Status:** accidental, and now a keeper.

> Note: picking a time of day in the sky menu drops a special that doesn't fit
> (weather goes back to clear), so the menu can't be used to get either egg. If we
> want the eggs to be deliberate, keep the key path unrestricted.

### Starlink train
- **How:** open the sky menu (G) when the sky is dark and clear (dusk or night, no
  cloud), then type **starlink**. The menu closes and a string of 24 satellites
  crosses the sky from the west-north-west to the south-east over about a minute.
- **Why this trigger:** the letters are not commands while the menu is open, so
  typing can't change the time or weather by accident, and the mouse is free there.
- **If it is too bright or cloudy:** the menu says a train needs a dark, clear sky.
- **Status:** built (D-123), checked headless and for shader compile, not yet seen
  in a running game by a person.

## Ideas (not built yet)

Add ideas here as one-liners: what the player does, and what happens.

- _(none yet)_
