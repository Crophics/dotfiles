// osd: a tiny volume/brightness popup for Wayland (wlr-layer-shell).
// Reads lines from a FIFO:   vol 55   |   vol 40 muted   |   bri 15
// and shows a rounded pill (icon, bar, percentage) near the top of the screen for ~1.2 s.
// Catppuccin Mocha colours, sized like the old quickshell popup (320x32).
use std::fs::File;
use std::os::fd::{AsFd, AsRawFd, FromRawFd, OwnedFd};
use std::time::{Duration, Instant};

use memmap2::MmapMut;
use wayland_client::protocol::{
    wl_buffer::{self, WlBuffer},
    wl_compositor::WlCompositor,
    wl_region::WlRegion,
    wl_registry::{self, WlRegistry},
    wl_shm::{self, WlShm},
    wl_shm_pool::WlShmPool,
    wl_surface::WlSurface,
};
use wayland_client::{delegate_noop, Connection, Dispatch, QueueHandle};
use wayland_protocols::wp::fractional_scale::v1::client::{
    wp_fractional_scale_manager_v1::WpFractionalScaleManagerV1,
    wp_fractional_scale_v1::{self, WpFractionalScaleV1},
};
use wayland_protocols::wp::viewporter::client::{wp_viewport::WpViewport, wp_viewporter::WpViewporter};
use wayland_protocols_wlr::layer_shell::v1::client::{
    zwlr_layer_shell_v1::{Layer, ZwlrLayerShellV1},
    zwlr_layer_surface_v1::{self, Anchor, KeyboardInteractivity, ZwlrLayerSurfaceV1},
};

const W: i32 = 320;
const H: i32 = 32;
const MARGIN_TOP: i32 = 30;
const BORDER: f64 = 2.0;
const FONT_TEXT: &str = "JetBrains Mono Bold 10";
const FONT_ICON: &str = "JetBrainsMono Nerd Font 13";

// Catppuccin Mocha
const BASE: (f64, f64, f64) = (0x1e as f64 / 255., 0x1e as f64 / 255., 0x2e as f64 / 255.);
const SURFACE1: (f64, f64, f64) = (0x45 as f64 / 255., 0x47 as f64 / 255., 0x5a as f64 / 255.);
const TEXT: (f64, f64, f64) = (0xcd as f64 / 255., 0xd6 as f64 / 255., 0xf4 as f64 / 255.);
const BLUE: (f64, f64, f64) = (0x89 as f64 / 255., 0xb4 as f64 / 255., 0xfa as f64 / 255.);
const RED: (f64, f64, f64) = (0xf3 as f64 / 255., 0x8b as f64 / 255., 0xa8 as f64 / 255.);

#[derive(Clone, Copy, PartialEq)]
enum Kind {
    Volume,
    Brightness,
}

/// Keeps a buffer's shared memory alive until the compositor releases the buffer.
#[allow(dead_code)]
struct BufData(MmapMut);

struct State {
    compositor: Option<WlCompositor>,
    shm: Option<WlShm>,
    layer_shell: Option<ZwlrLayerShellV1>,
    frac_mgr: Option<WpFractionalScaleManagerV1>,
    viewporter: Option<WpViewporter>,

    surface: Option<WlSurface>,
    layer: Option<ZwlrLayerSurfaceV1>,
    viewport: Option<WpViewport>,
    frac: Option<WpFractionalScaleV1>,
    configured: bool,
    visible: bool,
    scale120: u32, // preferred scale in 1/120ths (120 = 1.0, 144 = 1.2)

    kind: Kind,
    value: i32,
    muted: bool,
    deadline: Instant,
    timeout: Duration,
}

// ---- drawing -------------------------------------------------------------------------------
fn rounded_rect(cr: &cairo::Context, x: f64, y: f64, w: f64, h: f64, r: f64) {
    use std::f64::consts::PI;
    cr.new_sub_path();
    cr.arc(x + w - r, y + r, r, -PI / 2.0, 0.0);
    cr.arc(x + w - r, y + h - r, r, 0.0, PI / 2.0);
    cr.arc(x + r, y + h - r, r, PI / 2.0, PI);
    cr.arc(x + r, y + r, r, PI, 3.0 * PI / 2.0);
    cr.close_path();
}

fn rgb(cr: &cairo::Context, c: (f64, f64, f64)) {
    cr.set_source_rgb(c.0, c.1, c.2);
}

/// Draw `s` vertically centred on `cy`. align: 0 = x is the left edge, 1 = right edge, 2 = centre.
fn text(cr: &cairo::Context, font: &str, s: &str, x: f64, cy: f64, align: u8, color: (f64, f64, f64)) {
    let layout = pangocairo::functions::create_layout(cr);
    layout.set_font_description(Some(&pango::FontDescription::from_string(font)));
    layout.set_text(s);
    let (w, h) = layout.pixel_size();
    let px = match align {
        1 => x - w as f64,
        2 => x - w as f64 / 2.0,
        _ => x,
    };
    rgb(cr, color);
    cr.move_to(px, cy - h as f64 / 2.0);
    pangocairo::functions::show_layout(cr, &layout);
}

fn icon(kind: Kind, value: i32, muted: bool) -> &'static str {
    match kind {
        Kind::Brightness => "\u{F00E0}",
        Kind::Volume if muted => "\u{F075F}",
        Kind::Volume if value <= 0 => "\u{F0581}",
        Kind::Volume if value < 34 => "\u{F057F}",
        Kind::Volume if value < 67 => "\u{F0580}",
        Kind::Volume => "\u{F057E}",
    }
}

/// Render the pill at `pw` x `ph` device pixels; returns the raw ARGB32 bytes.
fn render(pw: i32, ph: i32, kind: Kind, value: i32, muted: bool) -> Vec<u8> {
    let mut surface = cairo::ImageSurface::create(cairo::Format::ARgb32, pw, ph).expect("cairo surface");
    {
        let cr = cairo::Context::new(&surface).expect("cairo context");
        cr.scale(pw as f64 / W as f64, ph as f64 / H as f64);
        let (w, h) = (W as f64, H as f64);

        // pill: border colour first, then the background inset by the border
        rgb(&cr, SURFACE1);
        rounded_rect(&cr, 0.0, 0.0, w, h, h / 2.0);
        let _ = cr.fill();
        rgb(&cr, BASE);
        rounded_rect(&cr, BORDER, BORDER, w - 2.0 * BORDER, h - 2.0 * BORDER, (h - 2.0 * BORDER) / 2.0);
        let _ = cr.fill();

        // icon (red when muted)
        let accent = if muted { RED } else { TEXT };
        text(&cr, FONT_ICON, icon(kind, value, muted), 24.0, h / 2.0, 2, accent);

        // bar: trough, then the fill (red when muted)
        let (bx, bw, bh) = (46.0, w - 46.0 - 62.0, 6.0);
        let by = (h - bh) / 2.0;
        rgb(&cr, SURFACE1);
        rounded_rect(&cr, bx, by, bw, bh, bh / 2.0);
        let _ = cr.fill();
        let v = value.clamp(0, 100);
        let mut fw = bw * v as f64 / 100.0;
        if fw > 0.0 {
            fw = fw.max(bh);
            rgb(&cr, if muted { RED } else { BLUE });
            rounded_rect(&cr, bx, by, fw, bh, bh / 2.0);
            let _ = cr.fill();
        }

        // percentage, right aligned
        text(&cr, FONT_TEXT, &format!("{v}%"), w - 22.0, h / 2.0, 1, TEXT);
    }
    surface.flush();
    let data = surface.data().expect("cairo data");
    data.to_vec()
}

// ---- state ---------------------------------------------------------------------------------
impl State {
    fn new(timeout: Duration) -> Self {
        State {
            compositor: None,
            shm: None,
            layer_shell: None,
            frac_mgr: None,
            viewporter: None,
            surface: None,
            layer: None,
            viewport: None,
            frac: None,
            configured: false,
            visible: false,
            scale120: 120,
            kind: Kind::Volume,
            value: 0,
            muted: false,
            deadline: Instant::now(),
            timeout,
        }
    }

    fn draw(&mut self, qh: &QueueHandle<State>) {
        let (Some(surface), Some(shm)) = (self.surface.as_ref(), self.shm.as_ref()) else { return };
        let pw = (W as u32 * self.scale120).div_ceil(120) as i32;
        let ph = (H as u32 * self.scale120).div_ceil(120) as i32;
        let stride = pw * 4;
        let size = (stride * ph) as usize;
        let pixels = render(pw, ph, self.kind, self.value, self.muted);

        let raw = unsafe { libc::memfd_create(c"osd".as_ptr(), libc::MFD_CLOEXEC) };
        if raw < 0 {
            eprintln!("osd: memfd_create failed");
            return;
        }
        let file = File::from(unsafe { OwnedFd::from_raw_fd(raw) });
        if file.set_len(size as u64).is_err() {
            return;
        }
        let Ok(mut map) = (unsafe { MmapMut::map_mut(&file) }) else { return };
        map[..size].copy_from_slice(&pixels[..size]);

        let pool: WlShmPool = shm.create_pool(file.as_fd(), size as i32, qh, ());
        let buf: WlBuffer = pool.create_buffer(0, pw, ph, stride, wl_shm::Format::Argb8888, qh, BufData(map));
        pool.destroy();

        surface.attach(Some(&buf), 0, 0);
        surface.damage_buffer(0, 0, pw, ph);
        surface.commit();
    }

    fn show(&mut self, qh: &QueueHandle<State>) {
        if self.surface.is_none() {
            let (Some(compositor), Some(layer_shell)) = (self.compositor.as_ref(), self.layer_shell.as_ref()) else {
                return;
            };
            let surface = compositor.create_surface(qh, ());
            let empty: WlRegion = compositor.create_region(qh, ()); // clicks pass through the popup
            surface.set_input_region(Some(&empty));
            empty.destroy();
            if let Some(vp) = self.viewporter.as_ref() {
                let viewport = vp.get_viewport(&surface, qh, ());
                viewport.set_destination(W, H);
                self.viewport = Some(viewport);
                if let Some(fm) = self.frac_mgr.as_ref() {
                    self.frac = Some(fm.get_fractional_scale(&surface, qh, ()));
                }
            }
            let layer = layer_shell.get_layer_surface(&surface, None, Layer::Overlay, "osd".into(), qh, ());
            layer.set_size(W as u32, H as u32);
            layer.set_anchor(Anchor::Top);
            layer.set_exclusive_zone(-1);
            layer.set_margin(MARGIN_TOP, 0, 0, 0);
            layer.set_keyboard_interactivity(KeyboardInteractivity::None);
            surface.commit();
            self.surface = Some(surface);
            self.layer = Some(layer);
        } else if self.configured {
            self.draw(qh);
        }
        self.visible = true;
        self.deadline = Instant::now() + self.timeout;
    }

    fn hide(&mut self) {
        if let Some(f) = self.frac.take() {
            f.destroy();
        }
        if let Some(v) = self.viewport.take() {
            v.destroy();
        }
        if let Some(l) = self.layer.take() {
            l.destroy();
        }
        if let Some(s) = self.surface.take() {
            s.destroy();
        }
        self.configured = false;
        self.visible = false;
    }

    fn handle_line(&mut self, line: &str, qh: &QueueHandle<State>) {
        let mut parts = line.split_whitespace();
        let kind = match parts.next() {
            Some("vol") => Kind::Volume,
            Some("bri") => Kind::Brightness,
            _ => return,
        };
        let Some(Ok(value)) = parts.next().map(str::parse::<i32>) else { return };
        self.kind = kind;
        self.value = value;
        self.muted = parts.next() == Some("muted");
        self.show(qh);
    }
}

// ---- wayland events ------------------------------------------------------------------------
impl Dispatch<WlRegistry, ()> for State {
    fn event(state: &mut Self, reg: &WlRegistry, event: wl_registry::Event, _: &(), _: &Connection, qh: &QueueHandle<Self>) {
        if let wl_registry::Event::Global { name, interface, version } = event {
            match interface.as_str() {
                "wl_compositor" => state.compositor = Some(reg.bind(name, version.min(4), qh, ())),
                "wl_shm" => state.shm = Some(reg.bind(name, 1, qh, ())),
                "zwlr_layer_shell_v1" => state.layer_shell = Some(reg.bind(name, version.min(4), qh, ())),
                "wp_fractional_scale_manager_v1" => state.frac_mgr = Some(reg.bind(name, 1, qh, ())),
                "wp_viewporter" => state.viewporter = Some(reg.bind(name, 1, qh, ())),
                _ => {}
            }
        }
    }
}

impl Dispatch<ZwlrLayerSurfaceV1, ()> for State {
    fn event(state: &mut Self, layer: &ZwlrLayerSurfaceV1, event: zwlr_layer_surface_v1::Event, _: &(), _: &Connection, qh: &QueueHandle<Self>) {
        match event {
            zwlr_layer_surface_v1::Event::Configure { serial, .. } => {
                layer.ack_configure(serial);
                state.configured = true;
                state.draw(qh);
            }
            zwlr_layer_surface_v1::Event::Closed => state.hide(),
            _ => {}
        }
    }
}

impl Dispatch<WpFractionalScaleV1, ()> for State {
    fn event(state: &mut Self, _: &WpFractionalScaleV1, event: wp_fractional_scale_v1::Event, _: &(), _: &Connection, qh: &QueueHandle<Self>) {
        if let wp_fractional_scale_v1::Event::PreferredScale { scale } = event {
            if scale != state.scale120 {
                state.scale120 = scale;
                if state.configured {
                    state.draw(qh);
                }
            }
        }
    }
}

impl Dispatch<WlBuffer, BufData> for State {
    fn event(_: &mut Self, buf: &WlBuffer, event: wl_buffer::Event, _: &BufData, _: &Connection, _: &QueueHandle<Self>) {
        if let wl_buffer::Event::Release = event {
            buf.destroy(); // the shared memory is freed once the buffer's data is dropped
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
delegate_noop!(State: ignore WlShm);
delegate_noop!(State: ignore WlSurface);

// ---- main ----------------------------------------------------------------------------------
fn main() {
    let mut fifo_path = format!("{}/osd.sock", std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into()));
    let mut timeout = Duration::from_millis(1200);
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        match a.as_str() {
            "--timeout" => {
                if let Some(ms) = args.next().and_then(|v| v.parse().ok()) {
                    timeout = Duration::from_millis(ms);
                }
            }
            "--fifo" => {
                if let Some(p) = args.next() {
                    fifo_path = p;
                }
            }
            _ => {}
        }
    }

    let conn = Connection::connect_to_env().unwrap_or_else(|e| {
        eprintln!("osd: cannot connect to Wayland: {e}");
        std::process::exit(1);
    });
    let mut queue = conn.new_event_queue();
    let qh = queue.handle();
    conn.display().get_registry(&qh, ());
    let mut state = State::new(timeout);
    queue.roundtrip(&mut state).expect("wayland roundtrip");
    if state.compositor.is_none() || state.shm.is_none() || state.layer_shell.is_none() {
        eprintln!("osd: compositor lacks wl_compositor, wl_shm or wlr-layer-shell");
        std::process::exit(1);
    }

    // The FIFO is opened read-write so writers never block and we never see EOF.
    let cpath = std::ffi::CString::new(fifo_path.clone()).unwrap();
    unsafe {
        libc::mkfifo(cpath.as_ptr(), 0o600);
    }
    let fifo = unsafe { libc::open(cpath.as_ptr(), libc::O_RDWR | libc::O_NONBLOCK) };
    if fifo < 0 {
        eprintln!("osd: cannot open {fifo_path}");
        std::process::exit(1);
    }

    let mut acc: Vec<u8> = Vec::new();
    loop {
        queue.dispatch_pending(&mut state).expect("dispatch");
        let _ = conn.flush();
        let Some(guard) = queue.prepare_read() else { continue };

        let mut fds = [
            libc::pollfd { fd: guard.connection_fd().as_raw_fd(), events: libc::POLLIN, revents: 0 },
            libc::pollfd { fd: fifo, events: libc::POLLIN, revents: 0 },
        ];
        let wait: i32 = if state.visible {
            state.deadline.saturating_duration_since(Instant::now()).as_millis() as i32
        } else {
            -1
        };
        let n = unsafe { libc::poll(fds.as_mut_ptr(), 2, wait) };
        if n > 0 && fds[0].revents & libc::POLLIN != 0 {
            match guard.read() {
                Ok(_) => {}
                Err(wayland_client::backend::WaylandError::Io(e)) if e.kind() == std::io::ErrorKind::WouldBlock => {}
                Err(e) => {
                    eprintln!("osd: wayland connection lost: {e}");
                    break;
                }
            }
        } else {
            drop(guard);
        }
        queue.dispatch_pending(&mut state).expect("dispatch");

        if n > 0 && fds[1].revents & libc::POLLIN != 0 {
            let mut chunk = [0u8; 256];
            let got = unsafe { libc::read(fifo, chunk.as_mut_ptr().cast(), chunk.len()) };
            if got > 0 {
                acc.extend_from_slice(&chunk[..got as usize]);
                while let Some(nl) = acc.iter().position(|&b| b == b'\n') {
                    let line: Vec<u8> = acc.drain(..=nl).collect();
                    state.handle_line(&String::from_utf8_lossy(&line), &qh);
                }
                if acc.len() > 512 {
                    acc.clear();
                }
            }
        }
        if state.visible && Instant::now() >= state.deadline {
            state.hide();
        }
    }
}
