# Marvel Champions Vertical Dividers - 3D OpenScad

Parametric OpenSCAD template for printing labeled divider cards, reverse-engineered
from a reference STL. Each card is a rounded-rectangle plate with a raised name
and a full-width ridge along the top edge — swap the name per print.

## What's here

```
mc-dividers/
├── divider.scad        # the parametric model
├── make-divider.sh     # wrapper: name -> stl/<slug>.stl
├── README.md
└── stl/                # generated STL output
```

## Requirements

- [OpenSCAD](https://openscad.org/) on your `PATH` (`openscad --version`).
- The **Marvel** font installed and visible to OpenSCAD. Check with:

  ```sh
  fc-list | grep -i marvel
  ```

  OpenSCAD looks fonts up by *family* name (the value reported by `fc-list`),
  not by the `.ttf` filename. To use a different font, edit `font` in
  `divider.scad`.

## Quick start

Generate a divider from a name:

```sh
./make-divider.sh "Jessica Jones"
```

This writes `stl/jessica-jones.stl`. The card text is always rendered in
**UPPERCASE** ("JESSICA JONES"), while the filename is lowercased with spaces
turned into hyphens.

Provide an explicit output path as a second argument to override the default:

```sh
./make-divider.sh "Spider Man" some/other/path.stl
```

The wrapper injects the name into the model at render time (via OpenSCAD's `-D`
flag), so `divider.scad` itself is never modified.

## Customizing the design

Open `divider.scad` in OpenSCAD and adjust the parameters at the top, or
override any of them from the command line with `-D name=value`. Key parameters:

### Text
| Parameter | Default | Meaning |
|---|---|---|
| `label` | `"JESSICA JONES"` | The name shown on the card. |
| `font` | `"Marvel:style=Regular"` | Font family (per `fc-list`). |
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
