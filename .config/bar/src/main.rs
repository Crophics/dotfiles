// bar: a small Hyprland status bar in Rust, replacing the quickshell bar.
// Same layout as before (strip style, top, 20 px): stats + workspaces + window | clock | media, volume,
// battery, network, power. Drawn with cairo + pango on a wlr-layer-shell surface.
use std::collections::{HashMap, HashSet};
use std::fs::File;
use std::io::{Read, Write};
use std::os::fd::{AsFd, AsRawFd, FromRawFd, OwnedFd};
use std::os::unix::net::UnixStream;
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

use memmap2::MmapMut;
use wayland_client::protocol::{
    wl_buffer::{self, WlBuffer},
    wl_compositor::WlCompositor,
    wl_pointer::{self, WlPointer},
    wl_region::WlRegion,
    wl_registry::{self, WlRegistry},
    wl_seat::{self, WlSeat},
    wl_shm::{self, WlShm},
    wl_shm_pool::WlShmPool,
    wl_surface::WlSurface,
};
use wayland_client::{delegate_noop, Connection, Dispatch, QueueHandle, WEnum};
use wayland_protocols::wp::cursor_shape::v1::client::{
    wp_cursor_shape_device_v1::{Shape, WpCursorShapeDeviceV1},
    wp_cursor_shape_manager_v1::WpCursorShapeManagerV1,
};
use wayland_protocols::wp::fractional_scale::v1::client::{
    wp_fractional_scale_manager_v1::WpFractionalScaleManagerV1,
    wp_fractional_scale_v1::{self, WpFractionalScaleV1},
};
use wayland_protocols::wp::viewporter::client::{wp_viewport::WpViewport, wp_viewporter::WpViewporter};
use wayland_protocols_wlr::layer_shell::v1::client::{
    zwlr_layer_shell_v1::{Layer, ZwlrLayerShellV1},
    zwlr_layer_surface_v1::{self, Anchor, KeyboardInteractivity, ZwlrLayerSurfaceV1},
};

// ---- look (the old quickshell bar: strip, 20 px, Catppuccin Mocha) --------------------------------
const BAR_H: f64 = 22.0;
const FONT_FAMILY: &str = "MesloLGS Nerd Font";
// One set of sizes for the whole bar. Everything (text, icons, spacing, corners, colours) comes from these.
const TEXT_PX: f64 = 13.0; // every piece of text, bar and tooltips, regular weight
const ICON_PX: f64 = 15.0; // every icon
const ICON_GAP: f64 = 6.0; // between an icon and its value
const MOD_PAD: f64 = 16.0; // total side padding of every item (half on each side)
const EDGE_GAP: f64 = 2.0; // bar edge to the first/last item
const RADIUS: f64 = 0.0; // hover/press shapes and tooltips: square, like the rest of the rice
type Col = (f64, f64, f64);
const fn hex(r: u8, g: u8, b: u8) -> Col {
    (r as f64 / 255., g as f64 / 255., b as f64 / 255.)
}
const BG: Col = hex(0x1e, 0x1e, 0x2e);
const TEXT: Col = hex(0xcd, 0xd6, 0xf4);
const FAINT: Col = hex(0x58, 0x5b, 0x70);
const EDGE: Col = hex(0x31, 0x32, 0x44); // the faint outline rofi uses too
const DANGER: Col = hex(0xf3, 0x8b, 0xa8);
const MARQUEE_W: f64 = 130.0;
const MARQUEE_GAP: f64 = 20.0;
const WINDOW_MAX_W: f64 = 260.0;
const TEXT_DY: f64 = 1.0; // text sits this many px higher, to match the old bar's vertical centring

const BTN_LEFT: u32 = 0x110;
const BTN_RIGHT: u32 = 0x111;
const BTN_MIDDLE: u32 = 0x112;

// ---- what clicking / scrolling does ----------------------------------------------------------------
#[derive(Clone, Copy, PartialEq, Debug)]
enum Act {
    None,
    Ws(i32),
    WsScroll,
    Special,
    Pavu,
    Mute,
    VolScroll,
    Net,
    Power,
    MediaToggle,
    MediaNext,
    MediaPrev,
}

#[derive(Clone)]
struct Hit {
    x0: f64,
    x1: f64,
    id: u32,
    l: Act,
    r: Act,
    m: Act,
    scroll: Act,
}
impl Hit {
    fn clickable(&self) -> bool {
        self.l != Act::None || self.r != Act::None || self.m != Act::None
    }
}

// ---- data shown ------------------------------------------------------------------------------------
#[derive(Clone, PartialEq, Default)]
struct Media {
    bus: String,
    playing: bool,
    title: String,
}

#[derive(Clone, PartialEq, Default)]
struct Data {
    cpu: i32,
    mem: i32,
    temp: i32,
    vol: i32,
    muted: bool,
    has_vol: bool,
    bat: i32,
    charging: bool,
    has_bat: bool,
    net: u8, // 0 none, 1 wifi, 2 ethernet
    time: String,
    ws: Vec<(i32, i32)>, // (id, windows)
    focused: i32,
    special: bool,
    urgent: Vec<i32>,
    win: Option<String>,
    media: Option<Media>,
}

#[derive(Clone)]
struct Anim {
    from: f64,
    to: f64,
    start: Instant,
    ms: f64,
    linear: bool,
}
impl Anim {
    fn new(from: f64, to: f64, ms: f64, linear: bool) -> Self {
        Anim { from, to, start: Instant::now(), ms, linear }
    }
    fn value(&self, now: Instant) -> f64 {
        let t = (now.saturating_duration_since(self.start).as_secs_f64() * 1000.0 / self.ms).min(1.0);
        let e = if self.linear { t } else { 1.0 - (1.0 - t).powi(3) }; // OutCubic, like the old bar
        self.from + (self.to - self.from) * e
    }
    fn active(&self, now: Instant) -> bool {
        now.saturating_duration_since(self.start).as_secs_f64() * 1000.0 < self.ms + 20.0
    }
}

#[derive(Default)]
struct Extra {
    mem_used_g: f64,
    mem_total_g: f64,
    bat_secs: i64,
    bat_state: u8, // 0 on battery, 1 charging, 2 full
    win_title: String,
}

#[derive(Default)]
struct Ui {
    hover: Option<u32>,
    pressed: Option<u32>,
    mq_x: i32,
    ul: Option<(Anim, Anim)>,       // workspace underline: x and width
    fade: HashMap<i32, Anim>,       // workspace text: 0 = unfocused, 1 = focused
}

struct Rendered {
    pixels: Vec<u8>,
    hits: Vec<Hit>,
    media_text_w: f64,
    media_max: f64,
    ul_target: Option<(f64, f64)>,
}

// ---- drawing helpers -------------------------------------------------------------------------------
fn font(px: f64, bold: bool) -> pango::FontDescription {
    let mut f = pango::FontDescription::new();
    f.set_family(FONT_FAMILY);
    f.set_absolute_size(px * pango::SCALE as f64);
    if bold {
        f.set_weight(pango::Weight::Bold);
    }
    f
}

fn layout(cr: &cairo::Context, s: &str, px: f64, bold: bool, max_w: Option<f64>) -> pango::Layout {
    let l = pangocairo::functions::create_layout(cr);
    l.set_font_description(Some(&font(px, bold)));
    l.set_text(s);
    if let Ok(mut o) = cairo::FontOptions::new() {
        o.set_hint_metrics(cairo::HintMetrics::Off); // unrounded character widths, like Qt
        pangocairo::functions::context_set_font_options(&l.context(), Some(&o));
        l.context_changed();
    }
    if let Some(w) = max_w {
        l.set_width((w * pango::SCALE as f64) as i32);
        l.set_ellipsize(pango::EllipsizeMode::End);
    }
    l
}

// Icons are measured with the same font as the text, so every item is spaced by one rule.
enum Seg<'a> {
    Text(&'a str),
    Glyph(char),
}

fn is_glyph(ch: char) -> bool {
    let c = ch as u32;
    (0xE000..0xF900).contains(&c) || c >= 0xF0000 || c == 0x23FB || c == 0x2726
}

fn glyph_adv(cr: &cairo::Context, ch: char, px: f64) -> f64 {
    // The wider of the font's reserved width and the icon's drawn width (some icons overhang their slot).
    let mut buf = [0u8; 4];
    let l = layout(cr, ch.encode_utf8(&mut buf), px, false, None);
    let (ink, logical) = l.extents();
    let s = pango::SCALE as f64;
    (logical.width() as f64 / s).max((ink.x() + ink.width()) as f64 / s)
}

fn segs(s: &str) -> Vec<Seg<'_>> {
    let mut v = Vec::new();
    let mut start = 0;
    for (i, ch) in s.char_indices() {
        if is_glyph(ch) {
            if start < i {
                v.push(Seg::Text(&s[start..i]));
            }
            v.push(Seg::Glyph(ch));
            start = i + ch.len_utf8();
        }
    }
    if start < s.len() {
        v.push(Seg::Text(&s[start..]));
    }
    v
}

fn pango_w(l: &pango::Layout) -> f64 {
    l.extents().1.width() as f64 / pango::SCALE as f64
}

fn text_w(cr: &cairo::Context, s: &str, px: f64, bold: bool) -> f64 {
    segs(s)
        .iter()
        .map(|g| match g {
            Seg::Glyph(c) => glyph_adv(cr, *c, px),
            Seg::Text(t) => pango_w(&layout(cr, t, px, bold, None)),
        })
        .sum::<f64>()
        .ceil() // Qt layouts round every item's width up to a whole logical pixel
}

fn paint(cr: &cairo::Context, l: &pango::Layout, x: f64, cy: f64, c: Col, a: f64) {
    let (_, h) = l.pixel_size();
    cr.set_source_rgba(c.0, c.1, c.2, a);
    cr.move_to(x, cy - h as f64 / 2.0 - TEXT_DY);
    pangocairo::functions::show_layout(cr, l);
}

fn draw_text(cr: &cairo::Context, s: &str, x: f64, cy: f64, px: f64, bold: bool, c: Col, a: f64, max_w: Option<f64>) -> f64 {
    let mut cx = x;
    for g in segs(s) {
        match g {
            Seg::Glyph(ch) => {
                let mut buf = [0u8; 4];
                let l = layout(cr, ch.encode_utf8(&mut buf), px, bold, None);
                paint(cr, &l, cx, cy, c, a);
                cx += glyph_adv(cr, ch, px);
            }
            Seg::Text(t) => {
                let remain = max_w.map(|m| (m - (cx - x)).max(0.0));
                let l = layout(cr, t, px, bold, remain);
                paint(cr, &l, cx, cy, c, a);
                cx += pango_w(&l);
            }
        }
    }
    cx - x
}

fn rounded(cr: &cairo::Context, x: f64, y: f64, w: f64, h: f64, r: f64) {
    let r = r.min(h / 2.0).min(w / 2.0);
    cr.new_sub_path();
    cr.arc(x + w - r, y + r, r, -std::f64::consts::FRAC_PI_2, 0.0);
    cr.arc(x + w - r, y + h - r, r, 0.0, std::f64::consts::FRAC_PI_2);
    cr.arc(x + r, y + h - r, r, std::f64::consts::FRAC_PI_2, std::f64::consts::PI);
    cr.arc(x + r, y + r, r, std::f64::consts::PI, 3.0 * std::f64::consts::FRAC_PI_2);
    cr.close_path();
}

// ---- the modules -----------------------------------------------------------------------------------
struct ModSpec {
    id: u32,
    glyph: String,
    gpx: f64,
    text: String,
    tpx: f64,
    bold: bool,
    spacing: f64,
    pad: f64,
    color: Col,
    warn: bool,
    l: Act,
    r: Act,
    m: Act,
    scroll: Act,
    yoff: f64,
}
impl ModSpec {
    fn new(id: u32) -> Self {
        ModSpec { id, glyph: String::new(), gpx: ICON_PX, text: String::new(), tpx: TEXT_PX, bold: false, spacing: ICON_GAP, pad: MOD_PAD, color: TEXT, warn: false, l: Act::None, r: Act::None, m: Act::None, scroll: Act::None, yoff: 0.0 }
    }
    fn width(&self, cr: &cairo::Context) -> f64 {
        let gw = text_w(cr, &self.glyph, self.gpx, false);
        let tw = text_w(cr, &self.text, self.tpx, self.bold);
        gw + if gw > 0.0 && tw > 0.0 { self.spacing } else { 0.0 } + tw + self.pad
    }
}

enum Kind {
    Mod(ModSpec),
    Ws,
    Win(String),
    Media(Media),
}
struct El {
    kind: Kind,
    w: f64,
}

fn ws_item_w(cr: &cairo::Context, label: &str) -> f64 {
    (text_w(cr, label, TEXT_PX, false) + MOD_PAD).max(24.0)
}

fn pretty(app: &str) -> String {
    app.replace(['-', '_', '.'], " ")
        .split(' ')
        .map(|w| {
            let mut c = w.chars();
            c.next().map(|f| f.to_uppercase().collect::<String>() + c.as_str()).unwrap_or_default()
        })
        .collect::<Vec<_>>()
        .join(" ")
}

fn text_w_clamped(cr: &cairo::Context, s: &str, px: f64, max: f64) -> f64 {
    text_w(cr, s, px, false).min(max)
}

fn media_text(m: &Media) -> String {
    format!("{} {}", if m.playing { "\u{F040A}" } else { "\u{F03E4}" }, m.title)
}

fn build_elements(cr: &cairo::Context, d: &Data, width: f64) -> (Vec<El>, Vec<El>, Vec<El>, f64) {
    let (mut start, mut center, mut end) = (Vec::new(), Vec::new(), Vec::new());
    let push = |v: &mut Vec<El>, kind: Kind, w: f64| v.push(El { kind, w });

    // stats: CPU, temperature, RAM (compact: icon + value)
    let stats: Vec<(u32, &str, i32, &str)> = if d.temp > 0 {
        vec![(1, "\u{F061A}", d.cpu, "%"), (2, "\u{F050F}", d.temp, "°"), (3, "\u{F035B}", d.mem, "%")]
    } else {
        vec![(1, "\u{F061A}", d.cpu, "%"), (3, "\u{F035B}", d.mem, "%")]
    };
    for (id, glyph, val, unit) in stats {
        let mut m = ModSpec::new(id);
        m.glyph = glyph.into();
        m.text = format!("{val}{unit}");
        m.warn = val >= 85;
        let w = m.width(cr);
        push(&mut start, Kind::Mod(m), w);
    }
    // workspaces
    let ws_w = if d.special {
        ws_item_w(cr, "\u{2726} scratchpad") + 8.0
    } else {
        let shown: Vec<&(i32, i32)> = d.ws.iter().filter(|(id, _)| *id > 0).collect();
        let items: f64 = shown.iter().map(|(id, _)| ws_item_w(cr, &id.to_string())).sum();
        items + (shown.len() as f64 - 1.0).max(0.0) * 2.0 + 8.0
    };
    push(&mut start, Kind::Ws, ws_w);
    // active window
    if let Some(name) = d.win.clone() {
        let w = text_w_clamped(cr, &name, TEXT_PX, WINDOW_MAX_W) + MOD_PAD;
        push(&mut start, Kind::Win(name), w);
    }

    // clock
    let mut clock = ModSpec::new(13);
    clock.text = d.time.clone();
    let w = clock.width(cr);
    push(&mut center, Kind::Mod(clock), w);

    // media
    if let Some(media) = d.media.clone() {
        let w = text_w(cr, &media_text(&media), TEXT_PX, false).min(MARQUEE_W) + MOD_PAD;
        push(&mut end, Kind::Media(media), w);
    }
    // volume
    if d.has_vol {
        let mut v = ModSpec::new(10);
        v.glyph = if d.muted || d.vol <= 0 { "\u{F075F}" } else { "\u{F057E}" }.into();
        v.warn = d.muted;
        v.l = Act::Pavu;
        v.r = Act::Mute;
        v.scroll = Act::VolScroll;
        let w = v.width(cr);
        push(&mut end, Kind::Mod(v), w);
    }
    // battery
    if d.has_bat {
        let icons = ["\u{f244}", "\u{f243}", "\u{f242}", "\u{f241}", "\u{f240}"];
        let b = d.bat;
        let icon = icons[if b >= 90 { 4 } else if b >= 65 { 3 } else if b >= 40 { 2 } else if b >= 15 { 1 } else { 0 }];
        let mut m = ModSpec::new(15);
        m.glyph = format!("{}{}", if d.charging { "\u{f0e7} " } else { "" }, icon);
        m.text = format!("{b}%");
        m.warn = !d.charging && b <= 15;
        let w = m.width(cr);
        push(&mut end, Kind::Mod(m), w);
    }
    // network
    let mut n = ModSpec::new(11);
    n.glyph = match d.net {
        1 => "\u{F05A9}",
        2 => "\u{F0200}",
        _ => "\u{F05AA}",
    }
    .into();
    n.warn = d.net == 0;
    n.l = Act::Net;
    let w = n.width(cr);
    push(&mut end, Kind::Mod(n), w);
    // power
    let mut p = ModSpec::new(12);
    p.glyph = "\u{23FB}".into();
    p.l = Act::Power;
    let w = p.width(cr);
    push(&mut end, Kind::Mod(p), w);

    // The music text may use all the free space between the clock and the right-hand icons; it only scrolls
    // when a title is longer than that.
    let clock_w: f64 = center.iter().map(|e| e.w).sum();
    let others: f64 = end.iter().filter(|e| !matches!(e.kind, Kind::Media(_))).map(|e| e.w).sum();
    let media_max = ((width - EDGE_GAP - others) - (width / 2.0 + clock_w / 2.0) - 12.0 - 20.0).max(MARQUEE_W);
    for e in end.iter_mut() {
        if let Kind::Media(m) = &e.kind {
            e.w = text_w(cr, &media_text(m), TEXT_PX, false).min(media_max) + MOD_PAD;
        }
    }
    (start, center, end, media_max)
}

fn render(d: &Data, ui: &Ui, pw: i32, ph: i32, width: f64, ul_cur: Option<(f64, f64)>, fade: &HashMap<i32, f64>) -> Rendered {
    let mut surface = cairo::ImageSurface::create(cairo::Format::ARgb32, pw, ph).expect("surface");
    let mut hits: Vec<Hit> = Vec::new();
    let mut media_text_w = 0.0;
    let media_max;
    let mut ul_target: Option<(f64, f64)> = None;
    {
        let cr = cairo::Context::new(&surface).expect("context");
        cr.scale(pw as f64 / width, ph as f64 / BAR_H);
        cr.set_source_rgb(BG.0, BG.1, BG.2);
        let _ = cr.paint();
        let cy = BAR_H / 2.0;

        let (start, center, end, mm) = build_elements(&cr, d, width);
        media_max = mm;
        let sum = |v: &Vec<El>| v.iter().map(|e| e.w).sum::<f64>();
        let sections = [(EDGE_GAP, &start), ((width - sum(&center)) / 2.0, &center), (width - EDGE_GAP - sum(&end), &end)];

        for (x0, els) in sections {
            let mut x = x0;
            for el in els.iter() {
                match &el.kind {
                    Kind::Mod(m) => {
                        let interactive = m.l != Act::None || m.r != Act::None;
                        let hovered = ui.hover == Some(m.id) && interactive;
                        let pressed = ui.pressed == Some(m.id) && hovered;
                        let tint = if pressed {
                            Some((TEXT, 0.18))
                        } else if m.warn {
                            Some((DANGER, 0.16))
                        } else {
                            None
                        };
                        if let Some((c, a)) = tint {
                            rounded(&cr, x + 1.0, 2.0, el.w - 2.0, BAR_H - 4.0, RADIUS);
                            cr.set_source_rgba(c.0, c.1, c.2, a);
                            let _ = cr.fill();
                        }
                        if hovered {
                            rounded(&cr, x + 1.0, 2.0, el.w - 2.0, BAR_H - 4.0, RADIUS);
                            cr.set_source_rgba(TEXT.0, TEXT.1, TEXT.2, 0.1);
                            let _ = cr.fill();
                        }
                        let fg = if m.warn { DANGER } else { m.color };
                        let gw = text_w(&cr, &m.glyph, m.gpx, false);
                        let tw = text_w(&cr, &m.text, m.tpx, m.bold);
                        let content = gw + if gw > 0.0 && tw > 0.0 { m.spacing } else { 0.0 } + tw;
                        let mut tx = x + (el.w - content) / 2.0;
                        let my = cy + m.yoff;
                        if gw > 0.0 {
                            draw_text(&cr, &m.glyph, tx, my, m.gpx, false, fg, 1.0, None);
                            tx += gw + if tw > 0.0 { m.spacing } else { 0.0 };
                        }
                        draw_text(&cr, &m.text, tx, my, m.tpx, m.bold, fg, 1.0, None);
                        hits.push(Hit { x0: x, x1: x + el.w, id: m.id, l: m.l, r: m.r, m: m.m, scroll: m.scroll });
                    }
                    Kind::Ws => {
                        hits.push(Hit { x0: x, x1: x + el.w, id: 99, l: Act::None, r: Act::None, m: Act::None, scroll: Act::WsScroll });
                        let mut ix = x + 4.0;
                        if d.special {
                            let label = "\u{2726} scratchpad";
                            let w = ws_item_w(&cr, label);
                            let tw = text_w(&cr, label, TEXT_PX, false);
                            draw_text(&cr, label, ix + (w - tw) / 2.0, cy, TEXT_PX, false, TEXT, 1.0, None);
                            ul_target = Some((ix + 4.0, w - 8.0));
                            hits.push(Hit { x0: ix, x1: ix + w, id: 98, l: Act::Special, r: Act::None, m: Act::None, scroll: Act::WsScroll });
                        } else {
                            for (id, windows) in d.ws.iter().filter(|(id, _)| *id > 0) {
                                let label = id.to_string();
                                let w = ws_item_w(&cr, &label);
                                let focused = *id == d.focused;
                                let hovered = ui.hover == Some(100 + *id as u32);
                                let f = fade.get(id).copied().unwrap_or(if focused { 1.0 } else { 0.0 });
                                let (bc, ba) = if *windows > 0 { (TEXT, 0.7) } else { (FAINT, 0.7) };
                                let (c, a) = if d.urgent.contains(id) {
                                    (DANGER, 1.0)
                                } else if hovered {
                                    (TEXT, 1.0)
                                } else {
                                    ((bc.0 + (TEXT.0 - bc.0) * f, bc.1 + (TEXT.1 - bc.1) * f, bc.2 + (TEXT.2 - bc.2) * f), ba + (1.0 - ba) * f)
                                };
                                let tw = text_w(&cr, &label, TEXT_PX, false);
                                draw_text(&cr, &label, ix + (w - tw) / 2.0, cy, TEXT_PX, false, c, a, None);
                                if focused {
                                    ul_target = Some((ix + 4.0, w - 8.0));
                                }
                                hits.push(Hit { x0: ix, x1: ix + w, id: 100 + *id as u32, l: Act::Ws(*id), r: Act::None, m: Act::None, scroll: Act::WsScroll });
                                ix += w + 2.0;
                            }
                        }
                    }
                    Kind::Win(name) => {
                        draw_text(&cr, name, x + MOD_PAD / 2.0, cy, TEXT_PX, false, TEXT, 1.0, Some(WINDOW_MAX_W));
                        hits.push(Hit { x0: x, x1: x + el.w, id: 16, l: Act::None, r: Act::None, m: Act::None, scroll: Act::None });
                    }
                    Kind::Media(media) => {
                        if ui.hover == Some(14) {
                            rounded(&cr, x + 1.0, 2.0, el.w - 2.0, BAR_H - 4.0, RADIUS);
                            cr.set_source_rgba(TEXT.0, TEXT.1, TEXT.2, 0.1);
                            let _ = cr.fill();
                        }
                        let s = media_text(media);
                        let full = text_w(&cr, &s, TEXT_PX, false);
                        media_text_w = full;
                        let vis = full.min(media_max);
                        let tx = x + MOD_PAD / 2.0;
                        let animating = media.playing && full > media_max;
                        cr.save().ok();
                        cr.rectangle(tx, 0.0, vis, BAR_H);
                        cr.clip();
                        if animating {
                            let ox = ui.mq_x as f64;
                            draw_text(&cr, &s, tx + ox, cy, TEXT_PX, false, TEXT, 1.0, None);
                            draw_text(&cr, &s, tx + ox + full + MARQUEE_GAP, cy, TEXT_PX, false, TEXT, 1.0, None);
                        } else {
                            draw_text(&cr, &s, tx, cy, TEXT_PX, false, TEXT, 1.0, Some(media_max));
                        }
                        cr.restore().ok();
                        hits.push(Hit { x0: x, x1: x + el.w, id: 14, l: Act::MediaToggle, r: Act::MediaNext, m: Act::MediaPrev, scroll: Act::None });
                    }
                }
                x += el.w;
            }
        }
    }
    if let Some((tx, tw)) = ul_target {
        let (ux, uw) = ul_cur.unwrap_or((tx, tw));
        let cr = cairo::Context::new(&surface).expect("context");
        cr.scale(pw as f64 / width, ph as f64 / BAR_H);
        cr.set_source_rgb(TEXT.0, TEXT.1, TEXT.2);
        cr.rectangle(ux, BAR_H - 2.0, uw, 2.0);
        let _ = cr.fill();
    }
    surface.flush();
    let pixels = surface.data().expect("data").to_vec();
    Rendered { pixels, hits, media_text_w, media_max, ul_target }
}

// ---- tooltips --------------------------------------------------------------------------------------
fn fmt_time(sec: i64) -> String {
    let (h, m) = (sec / 3600, (sec % 3600) / 60);
    if h > 0 { format!("{h}h {m}m") } else { format!("{m}m") }
}

fn tip_text(id: u32, d: &Data, x: &Extra) -> String {
    match id {
        1 => format!("CPU usage: {}%", d.cpu),
        2 => format!("CPU temperature: {} °C", d.temp),
        3 => format!("Memory: {:.1} / {:.1} GiB ({}%)", x.mem_used_g, x.mem_total_g, d.mem),
        10 => if d.muted { "Volume: muted".into() } else { format!("Volume: {}%", d.vol) },
        11 => match d.net { 1 => "Wi-Fi connected", 2 => "Ethernet connected", _ => "Disconnected" }.into(),
        12 => "Power menu".into(),
        15 => {
            let st = match x.bat_state { 2 => "fully charged", 1 => "charging", _ => "on battery" };
            let mut t = format!("Battery {}% · {}", d.bat, st);
            if x.bat_secs > 0 && x.bat_state != 2 {
                t += &format!(" · {} {}", fmt_time(x.bat_secs), if x.bat_state == 1 { "to full" } else { "left" });
            }
            t
        }
        16 => {
            let name = d.win.clone().unwrap_or_default();
            if x.win_title.is_empty() || x.win_title == name { name } else { format!("{name}: {}", x.win_title) }
        }
        98 => "Scratchpad".into(),
        i if i > 100 => {
            let ws = (i - 100) as i32;
            format!("Workspace {ws}{}", if d.urgent.contains(&ws) { " · urgent" } else if ws == d.focused { " · focused" } else { "" })
        }
        _ => String::new(),
    }
}

fn render_tip(text: &str, w: f64, h: f64, pw: i32, ph: i32) -> Vec<u8> {
    let mut surface = cairo::ImageSurface::create(cairo::Format::ARgb32, pw, ph).expect("surface");
    {
        let cr = cairo::Context::new(&surface).expect("context");
        cr.scale(pw as f64 / w, ph as f64 / h);
        rounded(&cr, 0.5, 0.5, w - 1.0, h - 1.0, RADIUS);
        cr.set_source_rgb(BG.0, BG.1, BG.2);
        let _ = cr.fill_preserve();
        cr.set_source_rgb(EDGE.0, EDGE.1, EDGE.2);
        cr.set_line_width(1.0);
        let _ = cr.stroke();
        let tw = text_w(&cr, text, TEXT_PX, false);
        draw_text(&cr, text, (w - tw) / 2.0, h / 2.0, TEXT_PX, false, TEXT, 1.0, None);
    }
    surface.flush();
    let pixels = surface.data().expect("data").to_vec();
    pixels
}

struct TipSurf {
    surface: WlSurface,
    layer: ZwlrLayerSurfaceV1,
    viewport: WpViewport,
    buf: Option<(WlBuffer, MmapMut)>,
    w: f64,
    h: f64,
    text: String,
}

// ---- wayland ---------------------------------------------------------------------------------------
struct Buf {
    map: MmapMut,
    wl: WlBuffer,
    busy: bool,
}

struct State {
    compositor: Option<WlCompositor>,
    shm: Option<WlShm>,
    layer_shell: Option<ZwlrLayerShellV1>,
    frac_mgr: Option<WpFractionalScaleManagerV1>,
    viewporter: Option<WpViewporter>,
    seat: Option<WlSeat>,
    cursor_mgr: Option<WpCursorShapeManagerV1>,
    pointer: Option<WlPointer>,
    cursor_dev: Option<WpCursorShapeDeviceV1>,
    surface: Option<WlSurface>,
    viewport: Option<WpViewport>,
    width: i32,
    configured: bool,
    scale120: u32,
    quit: bool,

    data: Data,
    ui: Ui,
    hits: Vec<Hit>,
    media_text_w: f64,
    media_max: f64,
    bufs: Vec<Buf>,
    buf_gen: u32,
    buf_dims: (i32, i32),
    pending_draw: bool,

    ptr_x: f64,
    ptr_in: bool,
    enter_serial: u32,
    cursor_clickable: Option<bool>,
    scroll_acc: f64,
    actions: Vec<(Act, u32)>, // queued by pointer events, run by the main loop

    extra: Extra,
    tip: Option<TipSurf>,
    tip_id: Option<(u32, f64, f64)>, // module under the pointer: id, x0, x1
    tip_since: Instant,
    tip_suppressed: bool, // set by a click; cleared when the pointer moves to another module
}

impl State {
    fn animating(&self, now: Instant) -> bool {
        self.ui.ul.as_ref().map(|(x, w)| x.active(now) || w.active(now)).unwrap_or(false) || self.ui.fade.values().any(|a| a.active(now))
    }

    fn hit_click(&self) -> Option<&Hit> {
        self.hits.iter().rev().find(|h| h.clickable() && self.ptr_x >= h.x0 && self.ptr_x < h.x1)
    }
    fn hit_scroll(&self) -> Option<&Hit> {
        self.hits.iter().rev().find(|h| h.scroll != Act::None && self.ptr_x >= h.x0 && self.ptr_x < h.x1)
    }

    fn hit_any(&self) -> Option<&Hit> {
        self.hits.iter().rev().find(|h| h.id != 99 && self.ptr_x >= h.x0 && self.ptr_x < h.x1)
    }

    fn hide_tip(&mut self) {
        if let Some(t) = self.tip.take() {
            if let Some((b, _)) = t.buf {
                b.destroy();
            }
            t.layer.destroy();
            t.viewport.destroy();
            t.surface.destroy();
        }
    }

    fn show_tip(&mut self, qh: &QueueHandle<State>) {
        let Some((id, x0, x1)) = self.tip_id else { return };
        let text = tip_text(id, &self.data, &self.extra);
        if text.is_empty() {
            return;
        }
        let (Some(comp), Some(ls), Some(vpr)) = (self.compositor.clone(), self.layer_shell.clone(), self.viewporter.clone()) else { return };
        let Ok(ms) = cairo::ImageSurface::create(cairo::Format::ARgb32, 1, 1) else { return };
        let Ok(mcr) = cairo::Context::new(&ms) else { return };
        let w = (text_w(&mcr, &text, TEXT_PX, false) + 20.0).ceil();
        let h = 30.0;
        let x = ((x0 + x1) / 2.0 - w / 2.0).clamp(0.0, (self.width as f64 - w).max(0.0));
        let surface = comp.create_surface(qh, ());
        let viewport = vpr.get_viewport(&surface, qh, ());
        let layer = ls.get_layer_surface(&surface, None, Layer::Overlay, "rbar-tip".into(), qh, 1u8);
        layer.set_size(w as u32, h as u32);
        layer.set_anchor(Anchor::Top | Anchor::Left);
        layer.set_margin(BAR_H as i32 + 5, 0, 0, x as i32);
        layer.set_exclusive_zone(-1);
        layer.set_keyboard_interactivity(KeyboardInteractivity::None);
        let region = comp.create_region(qh, ());
        surface.set_input_region(Some(&region)); // never takes the pointer
        region.destroy();
        surface.commit();
        self.tip = Some(TipSurf { surface, layer, viewport, buf: None, w, h, text });
    }

    fn tip_configure(&mut self, qh: &QueueHandle<State>) {
        let Some(shm) = self.shm.clone() else { return };
        let Some(mut t) = self.tip.take() else { return };
        if t.buf.is_none() {
            let pw = (t.w * self.scale120 as f64 / 120.0).ceil() as i32;
            let ph = (t.h * self.scale120 as f64 / 120.0).ceil() as i32;
            let pixels = render_tip(&t.text, t.w, t.h, pw, ph);
            let size = (pw * 4 * ph) as usize;
            let raw = unsafe { libc::memfd_create(c"bar-tip".as_ptr(), libc::MFD_CLOEXEC) };
            if raw >= 0 {
                let file = File::from(unsafe { OwnedFd::from_raw_fd(raw) });
                if file.set_len(size as u64).is_ok() {
                    if let Ok(mut map) = unsafe { MmapMut::map_mut(&file) } {
                        map[..size].copy_from_slice(&pixels[..size]);
                        let pool: WlShmPool = shm.create_pool(file.as_fd(), size as i32, qh, ());
                        let buf = pool.create_buffer(0, pw, ph, pw * 4, wl_shm::Format::Argb8888, qh, (u32::MAX, 0usize));
                        pool.destroy();
                        t.viewport.set_destination(t.w as i32, t.h as i32);
                        t.surface.attach(Some(&buf), 0, 0);
                        t.surface.damage_buffer(0, 0, pw, ph);
                        t.surface.commit();
                        t.buf = Some((buf, map));
                    }
                }
            }
        }
        self.tip = Some(t);
    }

    fn update_hover(&mut self, qh: &QueueHandle<State>) {
        let tid = if self.ptr_in { self.hit_any().map(|h| (h.id, h.x0, h.x1)) } else { None };
        if tid.map(|t| t.0) != self.tip_id.map(|t| t.0) {
            self.hide_tip();
            self.tip_since = Instant::now();
            self.tip_suppressed = false;
        }
        self.tip_id = tid;
        let id = if self.ptr_in { self.hit_click().map(|h| h.id) } else { None };
        let clickable = id.is_some();
        if self.cursor_clickable != Some(clickable) && self.ptr_in {
            self.cursor_clickable = Some(clickable);
            if let Some(dev) = self.cursor_dev.as_ref() {
                dev.set_shape(self.enter_serial, if clickable { Shape::Pointer } else { Shape::Default });
            }
        }
        if id != self.ui.hover {
            self.ui.hover = id;
            self.draw(qh);
        }
    }

    fn ensure_bufs(&mut self, qh: &QueueHandle<State>, pw: i32, ph: i32) -> bool {
        if self.buf_dims != (pw, ph) {
            for b in self.bufs.drain(..) {
                b.wl.destroy();
            }
            self.buf_gen += 1;
            self.buf_dims = (pw, ph);
        }
        if self.bufs.len() == 2 {
            return true;
        }
        let Some(shm) = self.shm.as_ref() else { return false };
        let (stride, size) = (pw * 4, (pw * 4 * ph) as usize);
        while self.bufs.len() < 2 {
            let raw = unsafe { libc::memfd_create(c"bar".as_ptr(), libc::MFD_CLOEXEC) };
            if raw < 0 {
                return false;
            }
            let file = File::from(unsafe { OwnedFd::from_raw_fd(raw) });
            if file.set_len(size as u64).is_err() {
                return false;
            }
            let Ok(map) = (unsafe { MmapMut::map_mut(&file) }) else { return false };
            let pool: WlShmPool = shm.create_pool(file.as_fd(), size as i32, qh, ());
            let idx = self.bufs.len();
            let wl = pool.create_buffer(0, pw, ph, stride, wl_shm::Format::Argb8888, qh, (self.buf_gen, idx));
            pool.destroy();
            self.bufs.push(Buf { map, wl, busy: false });
        }
        true
    }

    fn draw(&mut self, qh: &QueueHandle<State>) {
        if !self.configured {
            return;
        }
        let pw = (self.width as u32 * self.scale120).div_ceil(120) as i32;
        let ph = (BAR_H as u32 * self.scale120).div_ceil(120) as i32;
        if !self.ensure_bufs(qh, pw, ph) {
            return;
        }
        let Some(idx) = self.bufs.iter().position(|b| !b.busy) else {
            self.pending_draw = true;
            return;
        };
        let now = Instant::now();
        // workspace text fades (linear, 120 ms)
        let targets: Vec<(i32, f64)> = self.data.ws.iter().map(|(id, _)| (*id, if *id == self.data.focused && !self.data.special { 1.0 } else { 0.0 })).collect();
        for (id, t) in targets {
            match self.ui.fade.get(&id) {
                None => {
                    self.ui.fade.insert(id, Anim::new(t, t, 1.0, true));
                }
                Some(a) if (a.to - t).abs() > 0.01 => {
                    let cur = a.value(now);
                    self.ui.fade.insert(id, Anim::new(cur, t, 120.0, true));
                }
                _ => {}
            }
        }
        let fade: HashMap<i32, f64> = self.ui.fade.iter().map(|(k, a)| (*k, a.value(now))).collect();
        let ul_cur = self.ui.ul.as_ref().map(|(x, w)| (x.value(now), w.value(now)));
        let out = render(&self.data, &self.ui, pw, ph, self.width as f64, ul_cur, &fade);
        // underline slide (OutCubic, 220 ms)
        if let Some((tx, tw)) = out.ul_target {
            match &self.ui.ul {
                None => self.ui.ul = Some((Anim::new(tx, tx, 1.0, false), Anim::new(tw, tw, 1.0, false))),
                Some((ax, aw)) if (ax.to - tx).abs() > 0.01 || (aw.to - tw).abs() > 0.01 => {
                    let (cx, cw) = ul_cur.unwrap_or((tx, tw));
                    self.ui.ul = Some((Anim::new(cx, tx, 220.0, false), Anim::new(cw, tw, 220.0, false)));
                }
                _ => {}
            }
        }
        self.hits = out.hits;
        self.media_text_w = out.media_text_w;
        self.media_max = out.media_max;
        let size = (pw * 4 * ph) as usize;
        let buf = &mut self.bufs[idx];
        buf.map[..size].copy_from_slice(&out.pixels[..size]);
        buf.busy = true;
        if let Some(s) = self.surface.as_ref() {
            s.attach(Some(&buf.wl), 0, 0);
            s.damage_buffer(0, 0, pw, ph);
            s.commit();
        }
    }
}

impl Dispatch<WlRegistry, ()> for State {
    fn event(state: &mut Self, reg: &WlRegistry, event: wl_registry::Event, _: &(), _: &Connection, qh: &QueueHandle<Self>) {
        if let wl_registry::Event::Global { name, interface, version } = event {
            match interface.as_str() {
                "wl_compositor" => state.compositor = Some(reg.bind(name, version.min(4), qh, ())),
                "wl_shm" => state.shm = Some(reg.bind(name, 1, qh, ())),
                "zwlr_layer_shell_v1" => state.layer_shell = Some(reg.bind(name, version.min(4), qh, ())),
                "wp_fractional_scale_manager_v1" => state.frac_mgr = Some(reg.bind(name, 1, qh, ())),
                "wp_viewporter" => state.viewporter = Some(reg.bind(name, 1, qh, ())),
                "wl_seat" => state.seat = Some(reg.bind(name, version.min(5), qh, ())),
                "wp_cursor_shape_manager_v1" => state.cursor_mgr = Some(reg.bind(name, 1, qh, ())),
                _ => {}
            }
        }
    }
}
impl Dispatch<WlSeat, ()> for State {
    fn event(state: &mut Self, seat: &WlSeat, event: wl_seat::Event, _: &(), _: &Connection, qh: &QueueHandle<Self>) {
        if let wl_seat::Event::Capabilities { capabilities: WEnum::Value(caps) } = event {
            if caps.contains(wl_seat::Capability::Pointer) && state.pointer.is_none() {
                let p = seat.get_pointer(qh, ());
                if let Some(m) = state.cursor_mgr.as_ref() {
                    state.cursor_dev = Some(m.get_pointer(&p, qh, ()));
                }
                state.pointer = Some(p);
            }
        }
    }
}
impl Dispatch<WlPointer, ()> for State {
    fn event(state: &mut Self, _: &WlPointer, event: wl_pointer::Event, _: &(), _: &Connection, qh: &QueueHandle<Self>) {
        match event {
            wl_pointer::Event::Enter { serial, surface_x, .. } => {
                state.ptr_in = true;
                state.enter_serial = serial;
                state.ptr_x = surface_x;
                state.cursor_clickable = None;
                state.update_hover(qh);
            }
            wl_pointer::Event::Leave { .. } => {
                state.ptr_in = false;
                state.ui.pressed = None;
                state.update_hover(qh);
            }
            wl_pointer::Event::Motion { surface_x, .. } => {
                state.ptr_x = surface_x;
                state.update_hover(qh);
            }
            wl_pointer::Event::Button { button, state: WEnum::Value(bs), .. } => {
                let hit = state.hit_click().cloned();
                match bs {
                    wl_pointer::ButtonState::Pressed => {
                        state.hide_tip();
                        state.tip_suppressed = true;
                        state.ui.pressed = hit.map(|h| h.id);
                        state.draw(qh);
                    }
                    wl_pointer::ButtonState::Released => {
                        let was = state.ui.pressed.take();
                        if let Some(h) = hit {
                            if was == Some(h.id) {
                                let act = match button {
                                    BTN_LEFT => h.l,
                                    BTN_RIGHT => h.r,
                                    BTN_MIDDLE => h.m,
                                    _ => Act::None,
                                };
                                if act != Act::None {
                                    state.actions.push((act, 0));
                                }
                            }
                        }
                        state.draw(qh);
                    }
                    _ => {}
                }
            }
            wl_pointer::Event::Axis { axis: WEnum::Value(wl_pointer::Axis::VerticalScroll), value, .. } => {
                state.scroll_acc += value;
                while state.scroll_acc.abs() >= 10.0 {
                    let dir = if state.scroll_acc < 0.0 { 1 } else { 0 }; // 1 = up
                    state.scroll_acc -= 10.0 * state.scroll_acc.signum();
                    if let Some(act) = state.hit_scroll().map(|h| h.scroll) {
                        state.actions.push((act, dir));
                    }
                }
            }
            _ => {}
        }
    }
}
impl Dispatch<ZwlrLayerSurfaceV1, u8> for State {
    fn event(state: &mut Self, layer: &ZwlrLayerSurfaceV1, event: zwlr_layer_surface_v1::Event, which: &u8, _: &Connection, qh: &QueueHandle<Self>) {
        if *which == 1 {
            match event {
                zwlr_layer_surface_v1::Event::Configure { serial, .. } => {
                    layer.ack_configure(serial);
                    state.tip_configure(qh);
                }
                zwlr_layer_surface_v1::Event::Closed => state.hide_tip(),
                _ => {}
            }
            return;
        }
        match event {
            zwlr_layer_surface_v1::Event::Configure { serial, width, .. } => {
                layer.ack_configure(serial);
                if width > 0 {
                    state.width = width as i32;
                }
                state.configured = true;
                if let Some(vp) = state.viewport.as_ref() {
                    vp.set_destination(state.width, BAR_H as i32);
                }
                state.draw(qh);
            }
            zwlr_layer_surface_v1::Event::Closed => state.quit = true,
            _ => {}
        }
    }
}
impl Dispatch<WpFractionalScaleV1, ()> for State {
    fn event(state: &mut Self, _: &WpFractionalScaleV1, event: wp_fractional_scale_v1::Event, _: &(), _: &Connection, qh: &QueueHandle<Self>) {
        if let wp_fractional_scale_v1::Event::PreferredScale { scale } = event {
            if scale != state.scale120 {
                state.scale120 = scale;
                state.draw(qh);
            }
        }
    }
}
impl Dispatch<WlBuffer, (u32, usize)> for State {
    fn event(state: &mut Self, _: &WlBuffer, event: wl_buffer::Event, data: &(u32, usize), _: &Connection, qh: &QueueHandle<Self>) {
        if let wl_buffer::Event::Release = event {
            if data.0 == state.buf_gen {
                if let Some(b) = state.bufs.get_mut(data.1) {
                    b.busy = false;
                }
                if state.pending_draw {
                    state.pending_draw = false;
                    state.draw(qh);
                }
            }
        }
    }
}
delegate_noop!(State: WlCompositor);
delegate_noop!(State: WlRegion);
delegate_noop!(State: WlShmPool);
delegate_noop!(State: WpViewporter);
delegate_noop!(State: WpViewport);
delegate_noop!(State: WpFractionalScaleManagerV1);
delegate_noop!(State: ZwlrLayerShellV1);
delegate_noop!(State: WpCursorShapeManagerV1);
delegate_noop!(State: WpCursorShapeDeviceV1);
delegate_noop!(State: ignore WlShm);
delegate_noop!(State: ignore WlSurface);

// ---- system data -----------------------------------------------------------------------------------
fn read(p: &str) -> String {
    std::fs::read_to_string(p).unwrap_or_default()
}

fn clock() -> String {
    unsafe {
        let t = libc::time(std::ptr::null_mut());
        let mut tm: libc::tm = std::mem::zeroed();
        libc::localtime_r(&t, &mut tm);
        let mut buf = [0u8; 64];
        let n = libc::strftime(buf.as_mut_ptr().cast(), buf.len(), c"%a, %m/%d  %-I:%M %P".as_ptr(), &tm);
        String::from_utf8_lossy(&buf[..n]).into_owned()
    }
}

struct Sources {
    prev_total: u64,
    prev_idle: u64,
    temp_path: Option<String>,
    bat_dir: Option<String>,
}

impl Sources {
    fn new() -> Self {
        let temp_path = (0..16)
            .map(|i| format!("/sys/class/hwmon/hwmon{i}"))
            .find(|h| read(&format!("{h}/name")).trim() == "coretemp")
            .map(|h| format!("{h}/temp1_input"));
        let bat_dir = std::fs::read_dir("/sys/class/power_supply").ok().and_then(|rd| {
            rd.flatten().map(|e| e.path().to_string_lossy().into_owned()).find(|p| read(&format!("{p}/type")).trim() == "Battery" && read(&format!("{p}/scope")).trim() != "Device")
        });
        Sources { prev_total: 0, prev_idle: 0, temp_path, bat_dir }
    }

    fn refresh(&mut self, d: &mut Data, x: &mut Extra) {
        let stat = read("/proc/stat");
        let f: Vec<u64> = stat.lines().next().unwrap_or("").split_whitespace().skip(1).take(8).filter_map(|x| x.parse().ok()).collect();
        if f.len() == 8 {
            let total: u64 = f.iter().sum();
            let idle = f[3] + f[4];
            if self.prev_total > 0 && total > self.prev_total {
                d.cpu = (100 * ((total - self.prev_total) - (idle - self.prev_idle)) / (total - self.prev_total)) as i32;
            }
            self.prev_total = total;
            self.prev_idle = idle;
        }
        let mi = read("/proc/meminfo");
        let kb = |k: &str| mi.lines().find(|l| l.starts_with(k)).and_then(|l| l.split_whitespace().nth(1)).and_then(|v| v.parse::<i64>().ok()).unwrap_or(0);
        let (total, avail) = (kb("MemTotal:"), kb("MemAvailable:"));
        if total > 0 {
            d.mem = (100 * (total - avail) / total) as i32;
            x.mem_used_g = (total - avail) as f64 / 1048576.0;
            x.mem_total_g = total as f64 / 1048576.0;
        }
        d.temp = self.temp_path.as_deref().map(|p| read(p).trim().parse::<i32>().unwrap_or(0) / 1000).unwrap_or(0);
        if let Some(dir) = self.bat_dir.as_deref() {
            d.has_bat = true;
            d.bat = read(&format!("{dir}/capacity")).trim().parse().unwrap_or(0);
            let st = read(&format!("{dir}/status"));
            d.charging = matches!(st.trim(), "Charging" | "Full" | "Not charging");
            let rd = |n: &str| read(&format!("{dir}/{n}")).trim().parse::<f64>().unwrap_or(0.0);
            let (have, full, rate) = if rd("energy_now") > 0.0 { (rd("energy_now"), rd("energy_full"), rd("power_now")) } else { (rd("charge_now"), rd("charge_full"), rd("current_now")) };
            x.bat_state = if st.trim() == "Full" { 2 } else if d.charging { 1 } else { 0 };
            x.bat_secs = if rate > 0.0 { (if d.charging { (full - have).max(0.0) } else { have } / rate * 3600.0) as i64 } else { 0 };
        }
        let eth = std::fs::read_dir("/sys/class/net")
            .map(|rd| {
                rd.flatten().any(|e| {
                    let n = e.file_name().to_string_lossy().into_owned();
                    (n.starts_with("en") || n.starts_with("eth")) && read(&format!("/sys/class/net/{n}/operstate")).trim() == "up"
                })
            })
            .unwrap_or(false);
        let wifi = read("/sys/class/net/wlan0/operstate").trim() == "up";
        d.net = if eth { 2 } else if wifi { 1 } else { 0 };
        d.time = clock();
    }
}

fn refresh_volume(d: &mut Data) {
    if let Ok(out) = Command::new("wpctl").args(["get-volume", "@DEFAULT_AUDIO_SINK@"]).output() {
        let s = String::from_utf8_lossy(&out.stdout);
        if let Some(v) = s.split_whitespace().nth(1).and_then(|v| v.parse::<f64>().ok()) {
            d.has_vol = true;
            d.vol = (v * 100.0).round() as i32;
            d.muted = s.contains("MUTED");
            return;
        }
    }
    d.has_vol = false;
}

// ---- Hyprland --------------------------------------------------------------------------------------
fn hypr_path(name: &str) -> Option<String> {
    Some(format!("{}/hypr/{}/{}", std::env::var("XDG_RUNTIME_DIR").ok()?, std::env::var("HYPRLAND_INSTANCE_SIGNATURE").ok()?, name))
}

fn hypr_req(cmd: &str) -> Option<serde_json::Value> {
    let mut s = UnixStream::connect(hypr_path(".socket.sock")?).ok()?;
    s.set_read_timeout(Some(Duration::from_millis(500))).ok()?;
    s.write_all(cmd.as_bytes()).ok()?;
    let mut out = String::new();
    s.read_to_string(&mut out).ok()?;
    serde_json::from_str(&out).ok()
}

fn refresh_workspaces(d: &mut Data) {
    if let Some(v) = hypr_req("j/workspaces") {
        let mut ws: Vec<(i32, i32)> = v
            .as_array()
            .map(|a| a.iter().filter_map(|w| Some((w["id"].as_i64()? as i32, w["windows"].as_i64()? as i32))).collect())
            .unwrap_or_default();
        ws.sort();
        d.ws = ws;
    }
    if let Some(v) = hypr_req("j/monitors") {
        if let Some(m) = v.as_array().and_then(|a| a.iter().find(|m| m["focused"].as_bool() == Some(true)).or(a.first())) {
            d.focused = m["activeWorkspace"]["id"].as_i64().unwrap_or(1) as i32;
            d.special = !m["specialWorkspace"]["name"].as_str().unwrap_or("").is_empty();
        }
    }
    let f = d.focused;
    d.urgent.retain(|w| *w != f);
}

fn desktop_names() -> HashMap<String, String> {
    let mut map = HashMap::new();
    let home = std::env::var("HOME").unwrap_or_default();
    for dir in ["/usr/share/applications".to_string(), format!("{home}/.local/share/applications")] {
        let Ok(rd) = std::fs::read_dir(&dir) else { continue };
        for e in rd.flatten() {
            let path = e.path();
            if path.extension().and_then(|x| x.to_str()) != Some("desktop") {
                continue;
            }
            let txt = read(&path.to_string_lossy());
            let mut name = None;
            let mut wm = None;
            for line in txt.lines() {
                if line.starts_with('[') && line != "[Desktop Entry]" {
                    break;
                }
                if let Some(v) = line.strip_prefix("Name=") {
                    name.get_or_insert(v.to_string());
                } else if let Some(v) = line.strip_prefix("StartupWMClass=") {
                    wm = Some(v.to_string());
                }
            }
            if let Some(n) = name {
                if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
                    map.entry(stem.to_lowercase()).or_insert(n.clone());
                }
                if let Some(w) = wm {
                    map.entry(w.to_lowercase()).or_insert(n);
                }
            }
        }
    }
    map
}

fn app_name(names: &HashMap<String, String>, class: &str) -> Option<String> {
    if class.is_empty() {
        return None;
    }
    Some(names.get(&class.to_lowercase()).cloned().unwrap_or_else(|| pretty(class)))
}

// ---- media (MPRIS over D-Bus) ----------------------------------------------------------------------
struct Mpris {
    conn: dbus::blocking::Connection,
    last_active: Option<String>,
    was_playing: HashSet<String>,
}

impl Mpris {
    fn new() -> Option<Self> {
        Some(Mpris { conn: dbus::blocking::Connection::new_session().ok()?, last_active: None, was_playing: HashSet::new() })
    }

    fn poll(&mut self) -> Option<Media> {
        use dbus::arg::PropMap;
        use dbus::blocking::stdintf::org_freedesktop_dbus::Properties;
        let t = Duration::from_millis(250);
        let bus = self.conn.with_proxy("org.freedesktop.DBus", "/org/freedesktop/DBus", t);
        let (names,): (Vec<String>,) = bus.method_call("org.freedesktop.DBus", "ListNames", ()).ok()?;
        let mut players: Vec<Media> = Vec::new();
        for n in names.into_iter().filter(|n| n.starts_with("org.mpris.MediaPlayer2.")) {
            let p = self.conn.with_proxy(n.as_str(), "/org/mpris/MediaPlayer2", t);
            let Ok(status): Result<String, _> = p.get("org.mpris.MediaPlayer2.Player", "PlaybackStatus") else { continue };
            let md: PropMap = p.get("org.mpris.MediaPlayer2.Player", "Metadata").unwrap_or_default();
            let title = md.get("xesam:title").and_then(|v| v.0.as_str()).unwrap_or("").to_string();
            let artist = md
                .get("xesam:artist")
                .and_then(|v| v.0.as_iter())
                .and_then(|mut it| it.next().and_then(|a| a.as_str().map(String::from)))
                .unwrap_or_default();
            let full = if artist.is_empty() { title } else { format!("{artist} - {title}") };
            players.push(Media { bus: n, playing: status == "Playing", title: full });
        }
        // remember the most recent player to start playing
        for m in &players {
            if m.playing && !self.was_playing.contains(&m.bus) {
                self.last_active = Some(m.bus.clone());
            }
        }
        self.was_playing = players.iter().filter(|m| m.playing).map(|m| m.bus.clone()).collect();
        let pick = self
            .last_active
            .as_ref()
            .and_then(|b| players.iter().position(|m| &m.bus == b))
            .or_else(|| players.iter().position(|m| m.playing))
            .or(if players.is_empty() { None } else { Some(0) })?;
        let m = players.swap_remove(pick);
        if m.title.is_empty() { None } else { Some(m) }
    }

    fn control(&mut self, bus: &str, method: &str) {
        self.last_active = Some(bus.to_string());
        let p = self.conn.with_proxy(bus, "/org/mpris/MediaPlayer2", Duration::from_millis(250));
        let _: Result<(), _> = p.method_call("org.mpris.MediaPlayer2.Player", method, ());
    }
}

// ---- running things --------------------------------------------------------------------------------
fn spawn(children: &mut Vec<Child>, prog: &str, args: &[&str]) {
    if let Ok(c) = Command::new(prog).args(args).stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null()).spawn() {
        children.push(c);
    }
}

fn hypr_dispatch(children: &mut Vec<Child>, expr: &str) {
    spawn(children, "hyprctl", &["dispatch", expr]);
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let test_bottom = args.iter().any(|a| a == "--bottom"); // test mode: bottom edge, reserves no space

    let conn = Connection::connect_to_env().expect("wayland");
    let mut queue = conn.new_event_queue();
    let qh = queue.handle();
    conn.display().get_registry(&qh, ());
    let mut state = State {
        compositor: None, shm: None, layer_shell: None, frac_mgr: None, viewporter: None, seat: None, cursor_mgr: None,
        pointer: None, cursor_dev: None, surface: None, viewport: None,
        width: 1600, configured: false, scale120: 120, quit: false,
        data: Data::default(), ui: Ui::default(), hits: Vec::new(), media_text_w: 0.0, media_max: MARQUEE_W,
        bufs: Vec::new(), buf_gen: 0, buf_dims: (0, 0), pending_draw: false,
        ptr_x: 0.0, ptr_in: false, enter_serial: 0, cursor_clickable: None, scroll_acc: 0.0, actions: Vec::new(),
        extra: Extra::default(), tip: None, tip_id: None, tip_since: Instant::now(), tip_suppressed: false,
    };
    queue.roundtrip(&mut state).expect("roundtrip");
    queue.roundtrip(&mut state).expect("roundtrip");

    let compositor = state.compositor.clone().expect("compositor");
    let surface = compositor.create_surface(&qh, ());
    if let Some(vp) = state.viewporter.as_ref() {
        state.viewport = Some(vp.get_viewport(&surface, &qh, ()));
        if let Some(fm) = state.frac_mgr.as_ref() {
            let _ = fm.get_fractional_scale(&surface, &qh, ());
        }
    }
    let layer = state.layer_shell.as_ref().expect("layer shell").get_layer_surface(&surface, None, Layer::Top, if test_bottom { "rbar-test" } else { "rbar" }.into(), &qh, 0u8);
    layer.set_size(0, BAR_H as u32);
    layer.set_anchor((if test_bottom { Anchor::Bottom } else { Anchor::Top }) | Anchor::Left | Anchor::Right);
    layer.set_exclusive_zone(if test_bottom { 0 } else { BAR_H as i32 });
    layer.set_keyboard_interactivity(KeyboardInteractivity::None);
    surface.commit();
    state.surface = Some(surface);

    // data
    let names = desktop_names();
    let mut src = Sources::new();
    src.refresh(&mut state.data, &mut state.extra);
    refresh_volume(&mut state.data);
    refresh_workspaces(&mut state.data);
    if let Some(v) = hypr_req("j/activewindow") {
        state.data.win = app_name(&names, v["class"].as_str().unwrap_or(""));
        state.extra.win_title = v["title"].as_str().unwrap_or("").to_string();
    }
    let mut mpris = Mpris::new();
    state.data.media = mpris.as_mut().and_then(|m| m.poll());

    let mut events = hypr_path(".socket2.sock").and_then(|p| UnixStream::connect(p).ok());
    if let Some(e) = events.as_ref() {
        let _ = e.set_nonblocking(true);
    }
    let mut acc = String::new();
    let mut children: Vec<Child> = Vec::new();
    let home = std::env::var("HOME").unwrap_or_default();

    let mut last_stats = Instant::now();
    let mut last_media = Instant::now();
    let mut last_vol = Instant::now();
    let mut mq_last_tick = Instant::now();
    let mut anim_last_tick = Instant::now();
    let mut mq_hold_until = Some(Instant::now() + Duration::from_millis(2500));
    let mut shown = state.data.clone();
    let mut last_title = state.data.media.as_ref().map(|m| m.title.clone());
    let mut last_animating = false;

    while !state.quit {
        queue.dispatch_pending(&mut state).expect("dispatch");
        let _ = conn.flush();
        let Some(guard) = queue.prepare_read() else { continue };

        let animating = state.data.media.as_ref().map(|m| m.playing).unwrap_or(false) && state.media_text_w > state.media_max;
        let now = Instant::now();
        let mut wait = Duration::from_secs(2).saturating_sub(now.duration_since(last_stats));
        wait = wait.min(Duration::from_secs(1).saturating_sub(now.duration_since(last_media)));
        wait = wait.min(Duration::from_secs(1).saturating_sub(now.duration_since(last_vol)));
        if state.tip.is_none() && !state.tip_suppressed && state.tip_id.is_some() {
            wait = wait.min(Duration::from_millis(450).saturating_sub(now.duration_since(state.tip_since)));
        }
        if state.animating(now) {
            wait = wait.min(Duration::from_millis(16).saturating_sub(now.duration_since(anim_last_tick)));
        }
        if animating {
            let w = match mq_hold_until {
                Some(t) => t.saturating_duration_since(now),
                None => Duration::from_millis(33).saturating_sub(now.duration_since(mq_last_tick)),
            };
            wait = wait.min(w);
        }
        let mut fds = vec![libc::pollfd { fd: guard.connection_fd().as_raw_fd(), events: libc::POLLIN, revents: 0 }];
        if let Some(e) = events.as_ref() {
            fds.push(libc::pollfd { fd: e.as_raw_fd(), events: libc::POLLIN, revents: 0 });
        }
        let n = unsafe { libc::poll(fds.as_mut_ptr(), fds.len() as u64, wait.as_millis().min(i32::MAX as u128) as i32 + 1) };
        if n > 0 && fds[0].revents & libc::POLLIN != 0 {
            match guard.read() {
                Ok(_) => {}
                Err(wayland_client::backend::WaylandError::Io(e)) if e.kind() == std::io::ErrorKind::WouldBlock => {}
                Err(e) => {
                    eprintln!("bar: wayland connection lost: {e}");
                    break;
                }
            }
        } else {
            drop(guard);
        }
        queue.dispatch_pending(&mut state).expect("dispatch");

        // Hyprland events
        let mut ws_dirty = false;
        if n > 0 && fds.len() > 1 && fds[1].revents & libc::POLLIN != 0 {
            let mut chunk = [0u8; 4096];
            if let Some(e) = events.as_mut() {
                match e.read(&mut chunk) {
                    Ok(0) => {
                        eprintln!("bar: Hyprland event socket closed");
                        events = None;
                    }
                    Ok(got) => acc.push_str(&String::from_utf8_lossy(&chunk[..got])),
                    Err(_) => {}
                }
            }
            while let Some(nl) = acc.find('\n') {
                let line: String = acc.drain(..=nl).collect();
                let line = line.trim();
                let Some((name, data)) = line.split_once(">>") else { continue };
                match name {
                    "workspacev2" | "focusedmonv2" | "createworkspacev2" | "destroyworkspacev2" | "openwindow" | "closewindow" | "movewindowv2" | "activespecial" | "moveworkspacev2" => ws_dirty = true,
                    "activewindow" => {
                        let (class, title) = data.split_once(',').unwrap_or((data, ""));
                        state.data.win = app_name(&names, class);
                        state.extra.win_title = title.to_string();
                    }
                    "urgent" => {
                        if let Some(v) = hypr_req("j/clients") {
                            let addr = format!("0x{data}");
                            if let Some(w) = v.as_array().and_then(|a| a.iter().find(|c| c["address"].as_str() == Some(addr.as_str()))) {
                                if let Some(id) = w["workspace"]["id"].as_i64() {
                                    let id = id as i32;
                                    if id != state.data.focused && !state.data.urgent.contains(&id) {
                                        state.data.urgent.push(id);
                                    }
                                }
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
        if ws_dirty {
            refresh_workspaces(&mut state.data);
        }

        // clicks and scrolls queued by pointer events
        for (act, dir) in std::mem::take(&mut state.actions) {
            match act {
                Act::Ws(id) => hypr_dispatch(&mut children, &format!("hl.dsp.focus({{workspace=\"{id}\"}})")),
                Act::WsScroll => hypr_dispatch(&mut children, &format!("hl.dsp.focus({{workspace=\"e{}\"}})", if dir == 1 { "+1" } else { "-1" })),
                Act::Special => spawn(&mut children, &format!("{home}/.config/hypr/scripts/scratchpad.sh"), &["toggle"]),
                Act::Pavu => spawn(&mut children, "pavucontrol", &[]),
                Act::Mute => {
                    spawn(&mut children, "wpctl", &["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
                    last_vol = Instant::now() - Duration::from_millis(900);
                }
                Act::VolScroll => {
                    spawn(&mut children, "wpctl", &["set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", if dir == 1 { "2%+" } else { "2%-" }]);
                    last_vol = Instant::now() - Duration::from_millis(900);
                }
                Act::Net => spawn(&mut children, "kitty", &["-e", "impala"]),
                Act::Power => spawn(&mut children, &format!("{home}/.config/hypr/scripts/powermenu.sh"), &[]),
                Act::MediaToggle | Act::MediaNext | Act::MediaPrev => {
                    if let (Some(m), Some(mp)) = (state.data.media.clone(), mpris.as_mut()) {
                        mp.control(&m.bus, match act { Act::MediaToggle => "PlayPause", Act::MediaNext => "Next", _ => "Previous" });
                        last_media = Instant::now() - Duration::from_millis(700);
                    }
                }
                Act::None => {}
            }
        }

        let now = Instant::now();
        if now.duration_since(last_stats) >= Duration::from_secs(2) {
            src.refresh(&mut state.data, &mut state.extra);
            last_stats = now;
            children.retain_mut(|c| matches!(c.try_wait(), Ok(None)));
        }
        if now.duration_since(last_vol) >= Duration::from_secs(1) {
            refresh_volume(&mut state.data);
            last_vol = now;
        }
        if now.duration_since(last_media) >= Duration::from_secs(1) {
            state.data.media = mpris.as_mut().and_then(|m| m.poll());
            last_media = now;
        }

        if state.tip.is_none() && !state.tip_suppressed && state.tip_id.is_some() && now.duration_since(state.tip_since) >= Duration::from_millis(450) {
            state.show_tip(&qh);
        }

        // marquee
        let title = state.data.media.as_ref().map(|m| m.title.clone());
        let animating = state.data.media.as_ref().map(|m| m.playing).unwrap_or(false) && state.media_text_w > state.media_max;
        if title != last_title || animating != last_animating {
            last_title = title;
            last_animating = animating;
            state.ui.mq_x = 0;
            mq_hold_until = Some(now + Duration::from_millis(2500));
        }
        let mut mq_moved = false;
        if animating {
            match mq_hold_until {
                Some(t) if now >= t => mq_hold_until = None,
                Some(_) => {}
                None => {
                    if now.duration_since(mq_last_tick) >= Duration::from_millis(33) {
                        mq_last_tick = now;
                        state.ui.mq_x -= 1;
                        if state.ui.mq_x as f64 <= -(state.media_text_w + MARQUEE_GAP) {
                            state.ui.mq_x = 0;
                            mq_hold_until = Some(now + Duration::from_millis(2500));
                        }
                        mq_moved = true;
                    }
                }
            }
        }

        let mut anim_tick = false;
        if state.animating(now) && now.duration_since(anim_last_tick) >= Duration::from_millis(14) {
            anim_last_tick = now;
            anim_tick = true;
        }
        if state.data != shown || mq_moved || anim_tick {
            shown = state.data.clone();
            state.draw(&qh);
        }
    }
}
