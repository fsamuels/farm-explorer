# What's new

The highlights of Farm Explorer, newest first. For the full technical history, see
[docs/project/decisions.md](docs/project/decisions.md).

This file is shown in the game's What's New dialog (the C key), so write it for
players. Every release block is a `## Date: Title` heading, then a one-line
`> summary` (at most 140 characters), then `- ` bullets. After editing it, run
`cd project && godot --headless -s ../tools/build_release_notes.gd` and commit the
regenerated `project/scripts/release_data.gd`; `tests/test_release_notes.gd`
fails if the two disagree.

## November 23: A tidier screen
> One hint bar along the bottom, a HUD that scales on big screens, a resizable minimap, and hints that fade when you're idle.
- **One hint bar.** Map, Sky, News and Help hints now sit together in a dark bar along the bottom instead of scattered over the minimap.
- **Fits big screens.** Text and panels grow on large and high-resolution windows so they stay easy to read.
- **Resize the minimap.** Press Tab to cycle it between medium, large and small.
- **Cleaner view.** The hint bar fades away after a few quiet seconds and comes back when you press a key or click.
- **Matching dialogs.** The Sky, News and Map panels now share one look.

## November 23: Mountains on the horizon
> The Blue Mountains now rise in the east and the wind-farm ridges in the west, with turbines that spin and blink red at night.
- **The land beyond the fence.** Real hills and plains reach out 80 km in every direction, built from USGS elevation data. They shift against the farm as you walk.
- **The Blue Mountains.** Snow-streaked ridges with dark forest on top, 35 to 65 km east, drawn a little taller than life so they stand out.
- **Wind turbines.** About 1,100 turbines stand where they really are, most of them on the Stateline ridge to the west and south-west. Their blades turn, and at night some flash red in time with each other.
- **Seasons.** Pick Summer or Winter in the sky menu (G). Winter puts snow on the mountains, and falling snow always brings winter.

## November 23: Easier to see
> The map, sky and news hints now stand out in bright daylight, and the controls help gets out of your way sooner.
- **Readable by day.** The M / G / C hints, the location line under the minimap, the F1 hint and the clock now sit on a soft dark backing instead of floating on the sky.
- **Help clears itself.** The controls panel hides after about five seconds of walking or driving. Press F1 to bring it back.

## November 23: Faster around the farm
> Hold Ctrl to super sprint, and glowing transport pads in the back pastures send you around the farm.
- **Super sprint.** Hold Ctrl while you move to run about three times as fast as
  normal. Shift still slows you to a walk.
- **Transport pads.** Five glowing blue pads in the back pastures, west and south of
  the Back Barn. Look at a pillar of light and press E to be sent to the next pad;
  the last one sends you back to the Back Barn.

## November 23: What's New
> The game now shows its own changelog and size: press C, or click the star under the minimap.
- **A What's New window.** Press C (or click "C — News" under the minimap) to see
  what changed in each release, newest first, with a one-line headline for each.
- **By the numbers.** The same window shows how big the game is: lines of code,
  scenes, 3D models, images, vehicles, decisions logged and commits.

## November 23: A UTV in the barn
> A yellow Cub Cadet 550 UTV you can drive, with a dump bed, now lives in the Front Barn.
- **A yellow Cub Cadet 550.** It's parked in the Front Barn's middle aisle, facing the
  big north opening. Press E to get in, then drive it like the cars: W / S gas and
  brake, A / D steer, Space handbrake. It's slower and tighter than the cars, with
  an open cab, headlights and a little single-cylinder engine note.
- **A dump bed.** Press B while driving to tip the bed up or back down. Slow down
  first, and you can only crawl while it's raised.

## November 23: Fixes
> The property lines now slope the right way, and the Starlink train looks better.
- **Property lines.** The north-west and south-west corners of the property line
  now slope the right way and join up with their neighbours; they had been drawn
  as mirror images.
- **A better Starlink train.** Longer, with each light a little dimmer.

## November 23: Front Barn stalls and fences
> The Front Barn's stalls, roof and neighbouring fences now match the photo.
- **The south stall is closed in,** and the Front Barn's roof now reads as a middle
  section with a side section each side, about a foot lower, as in the photo.
- **Open stalls.** The stall walls are now four spaced boards instead of solid
  walls, so you can see through them like in the photo.
- **Fences meet the barn.** Three fences that stopped just short of the Front Barn
  now join it.

## November 22: The Front Barn, as it really is
> The Front Barn was rebuilt to look like the real one, and the map teleports you to its north side.
- **A barn that looks like the real one.** The Front Barn now has a tall middle with
  a low roof and a lower wing on each side, tan vertical siding, a big open middle
  bay, red roof trim and wood posts. Only the tack-room end is closed in, with a
  blue metal skirt along the bottom. The siding and posts are generated textures,
  not a photo laid over the walls.
- **Teleport to the north side.** Double-clicking the Front Barn on the map now puts
  you in front of the big opening on its north side, as in the photo, instead of at
  the south end.

## November 21: Weather, sky, cars and open doors
> Real weather, a night sky with a moon and planets, a sky menu, drivable cars and walk-in buildings.
- **A better night.** A full moon now rises and sets, lights the night and washes
  out the dimmer stars while it is high; the sky menu can turn it off for darker
  skies. Shooting stars can be turned off or turned up to a shower, and
  constellation names only show at night. The names button now controls both the
  names and the lines.
- **Look closely.** Something is hiding in the night sky. Try typing a word in the
  sky menu.
- **Tidier screen.** The controls panel tucks itself away when you press any key
  other than a moving one, and the sky menu's Clear button now sits top centre.
- **The Back Barn opens up.** It now has the Shop's blue metal walls and a big
  sliding barn door on its east and west sides.
- **Step inside.** Sally's House and the Front Barn are now enterable. The barn has
  three stalls, a tack room and a stack of hay, and the Shop has working doors.
- **Tidier property lines.** The north-west edge now follows the road instead of
  running out into the field beyond it, and the south-west corner is cut back with a
  straight line. Both are stand-ins until there is more drone imagery.
- **A real pole barn.** The Front Barn is now open on its north, south and east
  sides, with posts at the corners, so you can walk straight in and see across the
  farm from inside. The tack room has the only door, with a cubby on each side of it.
- **Take the wheel.** Drive the Triumph TR6 and the BMW 2002 tii, with engine
  sound, a speedometer and a view from the driver's seat.
- **A real night sky.** Stars, the Milky Way, constellation lines you can label,
  and the northern lights.
- **Weather that changes the world.** Fog, rain, snow, thunderstorms and rainbows,
  with wet ground, puddles and snow that settles.
- **Wildfire smoke.** Smoke haze and heavy smoke turn the light orange and drop a
  little ash.
- **Look up.** A sun by day, a moon at night, Venus, Mars, Jupiter and Saturn where
  they really are, and the occasional shooting star.
- **Pick your sky.** A new sky menu (G) sets the time of day and the weather
  directly, and a clock can run the day for you.
- **Easier to use.** A clearer "press E" prompt, and a clock readout in the corner.

## November 20: Meet the explorer
> You now appear in the game as a character, with a full map and a time of day.
- **You're in the game.** A player character you can walk around as, with a
  third-person view and a controls overlay.
- **A map of the whole ranch.** A full-screen map with labeled buildings and a
  coordinate grid.
- **Time of day.** Sunrise, day, sunset, dusk, night and dawn, plus rain, snow and
  dawn weather.
- **Camera control.** Keyboard camera keys and mouse-wheel zoom.

## September–October: The ranch takes shape
> Fences, aerial imagery, buildings, animals, cars and a web version of the ranch.
- **Fences and gates.** Pastures, barn lots, the round pen, the track and the
  gates between them, all traced from the real property.
- **Aerial imagery.** The ground is textured from drone photos of the ranch, and
  the buildings were lined up to match.
- **More buildings.** Sally's House, sheds, lean-tos, the pump house and the
  shipping container.
- **Animals.** Horses, chickens, ducks and a coyote.
- **Cars.** A parked Triumph TR6 and a BMW 2002 tii in Sally's driveway.
- **A minimap and a bigger window.**
- **Play it in your browser.** A web version you can play on itch.io.

## September 14: The first version
> A walkable 3D model of Reign Cloud Ranch built from the real parcel and satellite imagery.
- A walkable 3D model of Reign Cloud Ranch in Touchet, WA, built from the real
  parcel boundary and satellite imagery.
