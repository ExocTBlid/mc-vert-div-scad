// ============================================================
//  Parametric Divider Template
//  Reverse-engineered from jessica-jones.stl
//
//  A rounded-rectangle card with raised text along the top edge.
//  Change `label` (and optionally the parameters below) to make
//  a new divider for each print.
//
//  Original STL geometry that this reproduces:
//    - Card:  75 x 105 mm, 1.0 mm base, ~2 mm rounded corners
//    - Text:  raised 0.5 mm, centered, ~8 mm tall band just below
//             the top edge.
//    - Ridge: a full-width raised bar (rule line) ~10 mm below the
//             top edge, ~1 mm thick, raised the same 0.5 mm.
// ============================================================

/* [Text] */
// The name/label shown raised on the card.
label = "JESSICA JONES";
// Font family (must be available to OpenSCAD; use the family name reported by
// `fc-list`, not the .ttf filename. See Help > Font List inside OpenSCAD).
font = "Marvel:style=Regular";
// Cap height of the text, in mm.
text_size = 8;
// Horizontal alignment on the card: "center", "left", "right".
text_halign = "center";
// When true, every label is stretched/squeezed in X to span the usable
// width (uniform look across dividers). When false, text keeps its natural
// proportions (matches the original STL). Long labels may overflow if false.
fit_to_width = false;

/* [Card body] */
// Card width (X), in mm.
card_w = 75;
// Card height (Y), in mm.
card_h = 105;
// Thickness of the flat base plate, in mm.
base_thickness = 1.0;
// Corner radius of the rounded rectangle, in mm.
corner_radius = 2.0;

/* [Raised text] */
// How far the text rises above the base plate, in mm.
emboss_height = 0.5;
// Gap from the top edge of the card down to the top of the text, in mm.
text_top_margin = 1.5;
// Clear margin kept on each side, in mm (used for alignment and fitting).
text_side_margin = 4;

/* [Ridge] */
// Draw the full-width ridge (rule line) beneath the text.
show_ridge = true;
// Distance from the top edge of the card to the CENTER of the ridge, in mm.
ridge_offset = 10;
// Thickness of the ridge in Y, in mm.
ridge_thickness = 1.0;
// Side inset of the ridge from the card edges, in mm (0 = full width).
ridge_side_inset = 0;

/* [Quality] */
// Facets for rounded corners / curves.
$fn = 64;

// ------------------------------------------------------------
//  Helpers
// ------------------------------------------------------------

// A rounded rectangle (2D), lower-left corner at the origin.
module rounded_rect(w, h, r) {
    hull()
        for (x = [r, w - r], y = [r, h - r])
            translate([x, y]) circle(r = r);
}

// The flat base plate.
module base_plate() {
    linear_extrude(height = base_thickness)
        rounded_rect(card_w, card_h, corner_radius);
}

// 2D text outline, top-aligned so glyph tops sit at the origin's Y.
module label_2d() {
    text(label,
         size    = text_size,
         font    = font,
         halign  = text_halign,
         valign  = "top");
}

// The raised text, placed in a band along the top edge.
module raised_text() {
    usable_w = card_w - 2 * text_side_margin;

    x_pos = text_halign == "left"  ? text_side_margin :
            text_halign == "right" ? card_w - text_side_margin :
                                      card_w / 2;
    y_top = card_h - text_top_margin;

    translate([x_pos, y_top, base_thickness])
        if (fit_to_width)
            // Force the label to span exactly usable_w in X, keep Y as-is.
            resize([usable_w, 0, 0], auto = false)
                linear_extrude(height = emboss_height) label_2d();
        else
            linear_extrude(height = emboss_height) label_2d();
}

// The full-width raised ridge (rule line) below the text.
module raised_ridge() {
    y_center = card_h - ridge_offset;
    translate([ridge_side_inset, y_center - ridge_thickness / 2, base_thickness])
        linear_extrude(height = emboss_height)
            square([card_w - 2 * ridge_side_inset, ridge_thickness]);
}

// ------------------------------------------------------------
//  Assembly
// ------------------------------------------------------------
module divider() {
    base_plate();
    raised_text();
    if (show_ridge) raised_ridge();
}

divider();
