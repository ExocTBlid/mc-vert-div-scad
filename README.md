# Marvel Champions Vertical Dividers - 3D OpenSCAD

Parametric OpenSCAD template for printing labeled divider cards, reverse-engineered
from a reference STL. Each card is a rounded-rectangle plate with a raised name
and a full-width ridge along the top edge — swap the name per print.

## What's here

```
mc-vert-div-scad/
├── divider.scad        # the parametric model
├── make-divider.sh     # render one name -> stl/<slug>.stl
├── fetch-names.sh      # pull hero/villain/encounter name lists from marvelcdb data
├── divider-menu.sh     # interactive / piped front-end over make-divider.sh
├── names/              # generated name lists (heroes.txt, villains.txt, encounters.txt)
├── stl/                # generated STL output
└── README.md
```

## Requirements

- [OpenSCAD](https://openscad.org/) on your `PATH` (`openscad --version`).
- The **BentonSans ExtraComp Black** font installed and visible to OpenSCAD.
  Check with:

  ```sh
  fc-list | grep -i benton
  ```

  OpenSCAD looks fonts up by *family* name (the value reported by `fc-list`),
  not by the file name. To use a different font, edit `font` in `divider.scad`.
  Note: whichever font you choose must contain the glyphs you need — hyphens,
  digits, and lowercase letters included. (The original Marvel font only had
  uppercase letters and a period, so hyphens and digits silently vanished from
  the card; BentonSans covers full printable ASCII.)

## Quick start

Generate a single divider from a name:

```sh
./make-divider.sh "Jessica Jones"
```

This writes `stl/jessica_jones.stl`. The card text is always rendered in
**UPPERCASE** ("JESSICA JONES"). The filename is lowercased, with spaces and
hyphens both collapsed to underscores (`_`); a hyphen you type still shows up in
the card text, it just doesn't appear in the filename.

Provide an explicit output path as a second argument to override the default:

```sh
./make-divider.sh "Spider Man" some/other/path.stl
```

The wrapper injects the name into the model at render time (via OpenSCAD's `-D`
flag), so `divider.scad` itself is never modified.

## Name lists

`fetch-names.sh` pulls Marvel Champions set names from the community data repo
([zzorba/marvelsdb-json-data](https://github.com/zzorba/marvelsdb-json-data)'s
`sets.json`) and writes three deduplicated, sorted lists into `names/`:

```sh
./fetch-names.sh
```

| File | Source (`card_set_type_code`) | Contents |
|---|---|---|
| `names/heroes.txt` | `hero` | Playable hero names. |
| `names/villains.txt` | `villain` | Villain names (stages like Rhino I/II/III collapse to one). |
| `names/encounters.txt` | `modular` | Encounter set names (e.g. "Bomb Scare"). |

Requires `curl` and `python3`.

## Interactive / batch generation

`divider-menu.sh` is a front-end over `make-divider.sh` with two modes.

**Interactive** (run in a terminal):

```sh
./divider-menu.sh
```

A menu lets you either:

- **Choose from a list** — pick one of the `names/*.txt` files, then select
  entries by number, range, mix, or all:
  - `1 3 5` — individual items (space or comma separated)
  - `2-6` — an inclusive range
  - `1 4-6 9` — any mix
  - `all` — every item in the list
- **Enter manually** — type names one at a time; a blank line finishes.

**Piped / custom list** (when stdin is not a terminal): reads one name per line,
skipping blank lines and `#` comments. No flag needed — it auto-detects the pipe.

```sh
cat my-list.txt | ./divider-menu.sh
printf 'Thor\nLoki\n' | ./divider-menu.sh
./divider-menu.sh < names/heroes.txt
```

Every name flows through `make-divider.sh`, so the uppercase text, preserved
hyphens, `_` filenames, and `stl/` output stay consistent across all paths.

## Customizing the design

Open `divider.scad` in OpenSCAD and adjust the parameters at the top, or
override any of them from the command line with `-D name=value`. Key parameters:

### Text
| Parameter | Default | Meaning |
|---|---|---|
| `label` | `"JESSICA JONES"` | The name shown on the card. |
| `font` | `"BentonSans ExtraComp Black:style=Regular"` | Font family (per `fc-list`). |
| `text_size` | `8` | Cap height of the text, in mm. |
| `text_halign` | `"center"` | Alignment: `"center"`, `"left"`, `"right"`. |
| `fit_to_width` | `false` | Stretch text to span the full usable width for a uniform look. When `false`, text keeps its natural proportions. |

### Card body
| Parameter | Default | Meaning |
|---|---|---|
| `card_w` | `75` | Card width (X), mm. |
| `card_h` | `105` | Card height (Y), mm. |
| `base_thickness` | `1.0` | Thickness of the flat base plate, mm. |
| `corner_radius` | `2.0` | Rounded-corner radius, mm. |

### Raised text
| Parameter | Default | Meaning |
|---|---|---|
| `emboss_height` | `0.5` | How far the text rises above the plate, mm. |
| `text_top_margin` | `1.5` | Gap from the top edge down to the top of the text, mm. |
| `text_side_margin` | `4` | Clear margin kept on each side, mm. |

### Ridge (the rule line under the text)
| Parameter | Default | Meaning |
|---|---|---|
| `show_ridge` | `true` | Draw the full-width ridge. |
| `ridge_offset` | `10` | Distance from the top edge to the ridge center, mm. |
| `ridge_thickness` | `1.0` | Ridge thickness in Y, mm. |
| `ridge_side_inset` | `0` | Inset from the card edges (`0` = full width), mm. |

### Example: override parameters directly

```sh
openscad -o stl/custom.stl \
  -D 'label="CAPTAIN AMERICA"' \
  -D 'text_size=7' \
  -D 'show_ridge=false' \
  divider.scad
```

## Design notes

The model reproduces three raised elements measured from the reference STL:

- A **rounded-rectangle card**: 75 × 105 mm, 1.0 mm thick, ~2 mm corner radius.
- **Raised text** along the top, embossed 0.5 mm proud of the plate.
- A **full-width ridge** (rule line) ~10 mm below the top edge, ~1 mm thick,
  raised the same 0.5 mm.

STL is only a triangle mesh, so the original could not be converted back into
clean OpenSCAD directly. Instead the mesh was measured (dimensions, layer
heights, feature positions) and rebuilt as this parametric template.
