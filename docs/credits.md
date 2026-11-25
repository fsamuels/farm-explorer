# Credits

Third-party assets used in this project that require attribution under their license.
CC0 assets (e.g. the horse model, see D-9 in
[decisions.md](project/decisions.md)) need no entry here — they're public domain.

## Data

| Asset | Creator | Source | License |
| --- | --- | --- | --- |
| Distant terrain elevations (`project/scripts/horizon_data.gd`, built by `tools/build_horizon_data.py`) | USGS 3D Elevation Program (3DEP), via The National Map `3DEPElevation` ImageServer | [elevation.nationalmap.gov](https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer) | US Government work, public domain |
| Driveable-world ground elevation (`project/scripts/world_data.gd`, built by `tools/build_world_data.py`) | USGS 3D Elevation Program (3DEP), via The National Map `3DEPElevation` ImageServer | [elevation.nationalmap.gov](https://elevation.nationalmap.gov/arcgis/rest/services/3DEPElevation/ImageServer) | US Government work, public domain |
| Road centrelines and names (`project/scripts/road_data.gd`, same tool) | U.S. Census Bureau TIGER/Line, via TIGERweb | [tigerweb.geo.census.gov](https://tigerweb.geo.census.gov/arcgis/rest/services/TIGERweb/Transportation/MapServer) | US Government work, public domain |
| Aerial photo of the whole world square (`project/textures/world/naip_world.jpg`, same tool, which also reads each road's surface from the full-resolution photo) | USDA National Agriculture Imagery Program (NAIP), via The National Map `USGSNAIPPlus` ImageServer | [imagery.nationalmap.gov](https://imagery.nationalmap.gov/arcgis/rest/services/USGSNAIPPlus/ImageServer) | US Government work, public domain |
| Wind turbine positions, hub heights and rotor sizes (same file) | U.S. Wind Turbine Database (USGS, Lawrence Berkeley National Laboratory, American Clean Power Association) | [energy.usgs.gov/uswtdb](https://energy.usgs.gov/uswtdb/) | Public domain |
| Star positions and magnitudes (`project/scripts/star_data.gd`, built by `tools/build_star_data.py`) | Yale Bright Star Catalogue, 5th revised ed. (Hoffleit & Warren); JSON conversion by Bretton Wade | [github.com/brettonw/YaleBrightStarCatalog](https://github.com/brettonw/YaleBrightStarCatalog) | Catalogue is public domain; the conversion is MIT |

## Models

| Asset | Creator | Source | License |
| --- | --- | --- | --- |
| Hen (`project/models/hen.glb`) | Poly by Google | [poly.pizza/m/8Unya0rw9tR](https://poly.pizza/m/8Unya0rw9tR) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| Rooster (`project/models/rooster.glb`) | Poly by Google | [poly.pizza/m/6NTegstc5Jy](https://poly.pizza/m/6NTegstc5Jy) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| Coyote (`project/models/coyote.glb`) | Poly by Google | [poly.pizza/m/auVAs_kT6nE](https://poly.pizza/m/auVAs_kT6nE) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| Mallard duck (`project/models/mallard_duck.glb`) | Poly by Google | [poly.pizza/m/frSLi6b6Vid](https://poly.pizza/m/frSLi6b6Vid) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| Duck (`project/models/duck_poly.glb`) | Poly by Google | [poly.pizza/m/6HpauUCfIAb](https://poly.pizza/m/6HpauUCfIAb) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| Duck (`project/models/duck_madtroll.glb`) | madtrollstudio | [poly.pizza/m/4plJcFXhim](https://poly.pizza/m/4plJcFXhim) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| Lesser snow goose (`project/models/goose.glb`) | Poly by Google | [poly.pizza/m/5d10ZQ9QzuS](https://poly.pizza/m/5d10ZQ9QzuS) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| Quail (`project/models/quail.glb`) | Poly by Google | [poly.pizza/m/4A0kLzM65Mg](https://poly.pizza/m/4A0kLzM65Mg) | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) |
| Triumph TR6 (`project/models/tr6.glb`) | Configcars | [sketchfab.com/3d-models/tr6-with-open-top-8a926ced77064fea803b5f2eaa220372](https://sketchfab.com/3d-models/tr6-with-open-top-8a926ced77064fea803b5f2eaa220372) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| Cub Cadet 550 UTV body (`project/models/ranger_ev.glb`, "Polaris RANGER EV Li-Ion (2018)", recoloured yellow and black, textures dropped, wheels and cargo box split out by `tools/build_ranger_ev_model.py`) | geyges | [sketchfab.com/3d-models/polaris-ranger-ev-li-ion-2018-fadfb59f09524370b9f8ca5a2be1ff77](https://sketchfab.com/3d-models/polaris-ranger-ev-li-ion-2018-fadfb59f09524370b9f8ca5a2be1ff77) | [Sketchfab Standard](https://sketchfab.com/licenses): use in derivative works, but the model file itself may not be redistributed on its own |
| BMW 2002 tii (`project/models/bmw_2002_tii.glb`) | Configcars / maxipub | [sketchfab.com/3d-models/bmw-2002-tii-dcd02d7ff8a14b8eb7312a8daafff02c](https://sketchfab.com/3d-models/bmw-2002-tii-dcd02d7ff8a14b8eb7312a8daafff02c) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
