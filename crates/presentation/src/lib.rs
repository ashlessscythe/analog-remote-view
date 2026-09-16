//! Live presentation window for captured frames (winit + wgpu).
//!
//! Milestone 4 shows the capture stream in a companion window. Transparent
//! Factorio-aligned overlay arrives in later milestones.

mod shader {
    pub const SOURCE: &str = r#"
struct VertexOutput {
    @builtin(position) clip_position: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

@vertex
fn vs_main(@builtin(vertex_index) index: u32) -> VertexOutput {
    // Fullscreen triangle covering clip space.
    var positions = array<vec2<f32>, 3>(
        vec2<f32>(-1.0, -1.0),
        vec2<f32>( 3.0, -1.0),
        vec2<f32>(-1.0,  3.0),
    );
    var uvs = array<vec2<f32>, 3>(
        vec2<f32>(0.0, 1.0),
        vec2<f32>(2.0, 1.0),
        vec2<f32>(0.0, -1.0),
    );
    var out: VertexOutput;
    out.clip_position = vec4<f32>(positions[index], 0.0, 1.0);
    out.uv = uvs[index];
    return out;
}

@group(0) @binding(0) var frame_tex: texture_2d<f32>;
@group(0) @binding(1) var frame_samp: sampler;

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    return textureSample(frame_tex, frame_samp, in.uv);
}
"#;
}

use std::sync::Arc;
use std::time::{Duration, Instant};

use analog_remote_view_capture::CaptureBackend;
use analog_remote_view_core::{Frame, PixelFormat};
use tracing::{debug, info, warn};
use winit::application::ApplicationHandler;
use winit::dpi::LogicalSize;
use winit::event::{ElementState, KeyEvent, WindowEvent};
use winit::event_loop::{ActiveEventLoop, ControlFlow, EventLoop};
use winit::keyboard::{Key, NamedKey};
use winit::window::{Window, WindowId};

const DEFAULT_WIDTH: u32 = 1280;
const DEFAULT_HEIGHT: u32 = 720;
const STATS_INTERVAL: Duration = Duration::from_secs(1);

type FirstFrameCallback = Box<dyn FnMut(&Frame)>;

/// Owns the companion presentation window and GPU resources.
#[derive(Debug, Default)]
pub struct Presenter {
    pub visible: bool,
}

impl Presenter {
    pub fn new() -> Self {
        Self { visible: false }
    }

    /// Run an interactive capture → display loop until the window closes.
    ///
    /// Expects `backend` to already have an active capture session.
    /// `on_first_frame` is invoked once with the first complete frame (e.g. PNG dump).
    pub fn run<B, F>(backend: &mut B, on_first_frame: F) -> anyhow::Result<()>
    where
        B: CaptureBackend,
        F: FnMut(&Frame) + 'static,
    {
        let event_loop = EventLoop::new()?;
        event_loop.set_control_flow(ControlFlow::Poll);

        let mut app = PresenterApp {
            backend,
            window: None,
            gpu: None,
            surface_configured: false,
            frames_total: 0,
            frames_window: 0,
            last_stats: Instant::now(),
            last_size: (0, 0),
            on_first_frame: Some(Box::new(on_first_frame)),
            exit_requested: false,
            error: None,
        };

        event_loop.run_app(&mut app)?;

        if let Some(err) = app.error {
            return Err(err);
        }
        Ok(())
    }

    pub fn show_frame(&mut self, _frame: &Frame) {
        self.visible = true;
    }

    pub fn hide(&mut self) {
        self.visible = false;
    }
}

struct PresenterApp<'a, B: CaptureBackend> {
    backend: &'a mut B,
    window: Option<Arc<Window>>,
    gpu: Option<GpuState>,
    surface_configured: bool,
    frames_total: u64,
    frames_window: u64,
    last_stats: Instant,
    last_size: (u32, u32),
    on_first_frame: Option<FirstFrameCallback>,
    exit_requested: bool,
    error: Option<anyhow::Error>,
}

impl<B: CaptureBackend> ApplicationHandler for PresenterApp<'_, B> {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        if self.window.is_some() {
            return;
        }

        let attrs = Window::default_attributes()
            .with_title("Analog Remote View")
            .with_inner_size(LogicalSize::new(DEFAULT_WIDTH, DEFAULT_HEIGHT));

        match event_loop.create_window(attrs) {
            Ok(window) => {
                let window = Arc::new(window);
                match GpuState::new(Arc::clone(&window)) {
                    Ok(gpu) => {
                        self.gpu = Some(gpu);
                        self.window = Some(window);
                        self.surface_configured = false;
                        info!("presentation window opened");
                    }
                    Err(err) => {
                        self.error = Some(err);
                        self.exit_requested = true;
                        event_loop.exit();
                    }
                }
            }
            Err(err) => {
                self.error = Some(anyhow::anyhow!("failed to create window: {err}"));
                self.exit_requested = true;
                event_loop.exit();
            }
        }
    }

    fn window_event(
        &mut self,
        event_loop: &ActiveEventLoop,
        _window_id: WindowId,
        event: WindowEvent,
    ) {
        match event {
            WindowEvent::CloseRequested => {
                self.shutdown(event_loop);
            }
            WindowEvent::KeyboardInput {
                event:
                    KeyEvent {
                        logical_key: Key::Named(NamedKey::Escape),
                        state: ElementState::Pressed,
                        ..
                    },
                ..
            } => {
                self.shutdown(event_loop);
            }
            WindowEvent::Resized(size) => {
                if let Some(gpu) = self.gpu.as_mut() {
                    gpu.resize(size.width, size.height);
                    self.surface_configured = size.width > 0 && size.height > 0;
                }
                if let Some(window) = &self.window {
                    window.request_redraw();
                }
            }
            WindowEvent::RedrawRequested => {
                if let Err(err) = self.on_redraw() {
                    warn!(error = %err, "presentation redraw failed");
                    self.error = Some(err);
                    self.shutdown(event_loop);
                }
            }
            _ => {}
        }
    }

    fn about_to_wait(&mut self, event_loop: &ActiveEventLoop) {
        if self.exit_requested {
            return;
        }

        match self.backend.next_frame() {
            Ok(Some(frame)) => {
                if let Err(err) = self.handle_frame(frame) {
                    self.error = Some(err);
                    self.shutdown(event_loop);
                    return;
                }
            }
            Ok(None) => {}
            Err(err) => {
                self.error = Some(err.into());
                self.shutdown(event_loop);
                return;
            }
        }

        if self.last_stats.elapsed() >= STATS_INTERVAL && self.frames_total > 0 {
            let elapsed = self.last_stats.elapsed().as_secs_f64().max(1e-6);
            let fps = self.frames_window as f64 / elapsed;
            println!(
                "display: frames={} size={}x{} ~{:.1} fps",
                self.frames_total, self.last_size.0, self.last_size.1, fps
            );
            info!(
                frames = self.frames_total,
                width = self.last_size.0,
                height = self.last_size.1,
                fps = format!("{fps:.1}"),
                "display stats"
            );
            self.frames_window = 0;
            self.last_stats = Instant::now();
        }

        if let Some(window) = &self.window {
            window.request_redraw();
        }
    }
}

impl<B: CaptureBackend> PresenterApp<'_, B> {
    fn shutdown(&mut self, event_loop: &ActiveEventLoop) {
        if self.exit_requested {
            return;
        }
        self.exit_requested = true;
        self.backend.stop_capture();
        println!(
            "Stopped. Displayed {} frame(s); last size {}x{}.",
            self.frames_total, self.last_size.0, self.last_size.1
        );
        event_loop.exit();
    }

    fn handle_frame(&mut self, frame: Frame) -> anyhow::Result<()> {
        self.frames_total += 1;
        self.frames_window += 1;
        self.last_size = (frame.width, frame.height);

        if let Some(mut cb) = self.on_first_frame.take() {
            cb(&frame);
        }

        if let Some(window) = &self.window {
            // Grow the window toward the first frame size once (keep user resizes after).
            if self.frames_total == 1 {
                let _ = window.request_inner_size(LogicalSize::new(
                    frame.width.max(320),
                    frame.height.max(240),
                ));
            }
        }

        if let Some(gpu) = self.gpu.as_mut() {
            gpu.upload_frame(&frame)?;
        }
        Ok(())
    }

    fn on_redraw(&mut self) -> anyhow::Result<()> {
        let Some(gpu) = self.gpu.as_mut() else {
            return Ok(());
        };
        if !self.surface_configured {
            let size = self
                .window
                .as_ref()
                .map(|w| w.inner_size())
                .unwrap_or_default();
            if size.width == 0 || size.height == 0 {
                return Ok(());
            }
            gpu.resize(size.width, size.height);
            self.surface_configured = true;
        }
        gpu.render()
    }
}

struct GpuState {
    window: Arc<Window>,
    device: wgpu::Device,
    queue: wgpu::Queue,
    surface: wgpu::Surface<'static>,
    config: wgpu::SurfaceConfiguration,
    pipeline: wgpu::RenderPipeline,
    bind_group_layout: wgpu::BindGroupLayout,
    sampler: wgpu::Sampler,
    frame_texture: Option<FrameTexture>,
    size: (u32, u32),
}

struct FrameTexture {
    texture: wgpu::Texture,
    bind_group: wgpu::BindGroup,
    width: u32,
    height: u32,
}

impl GpuState {
    fn new(window: Arc<Window>) -> anyhow::Result<Self> {
        let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor {
            backends: wgpu::Backends::PRIMARY,
            ..Default::default()
        });
        let surface = instance.create_surface(Arc::clone(&window))?;
        let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
            power_preference: wgpu::PowerPreference::HighPerformance,
            compatible_surface: Some(&surface),
            force_fallback_adapter: false,
        }))
        .ok_or_else(|| anyhow::anyhow!("no suitable wgpu adapter"))?;

        let (device, queue) = pollster::block_on(adapter.request_device(
            &wgpu::DeviceDescriptor {
                label: Some("arv-presenter"),
                required_features: wgpu::Features::empty(),
                required_limits: wgpu::Limits::default(),
                memory_hints: wgpu::MemoryHints::Performance,
            },
            None,
        ))?;

        let size = window.inner_size();
        let width = size.width.max(1);
        let height = size.height.max(1);
        let caps = surface.get_capabilities(&adapter);
        let format = caps
            .formats
            .iter()
            .copied()
            .find(|f| f.is_srgb())
            .unwrap_or(caps.formats[0]);

        let config = wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            format,
            width,
            height,
            present_mode: wgpu::PresentMode::AutoVsync,
            alpha_mode: caps.alpha_modes[0],
            view_formats: vec![],
            desired_maximum_frame_latency: 2,
        };
        surface.configure(&device, &config);

        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("arv-frame-shader"),
            source: wgpu::ShaderSource::Wgsl(shader::SOURCE.into()),
        });

        let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
            label: Some("arv-frame-bgl"),
            entries: &[
                wgpu::BindGroupLayoutEntry {
                    binding: 0,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Texture {
                        sample_type: wgpu::TextureSampleType::Float { filterable: true },
                        view_dimension: wgpu::TextureViewDimension::D2,
                        multisampled: false,
                    },
                    count: None,
                },
                wgpu::BindGroupLayoutEntry {
                    binding: 1,
                    visibility: wgpu::ShaderStages::FRAGMENT,
                    ty: wgpu::BindingType::Sampler(wgpu::SamplerBindingType::Filtering),
                    count: None,
                },
            ],
        });

        let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            label: Some("arv-pipeline-layout"),
            bind_group_layouts: &[&bind_group_layout],
            push_constant_ranges: &[],
        });

        let pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("arv-frame-pipeline"),
            layout: Some(&pipeline_layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: Some("vs_main"),
                compilation_options: Default::default(),
                buffers: &[],
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: Some("fs_main"),
                compilation_options: Default::default(),
                targets: &[Some(wgpu::ColorTargetState {
                    format: config.format,
                    blend: Some(wgpu::BlendState::REPLACE),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
            }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview: None,
            cache: None,
        });

        let sampler = device.create_sampler(&wgpu::SamplerDescriptor {
            label: Some("arv-frame-sampler"),
            mag_filter: wgpu::FilterMode::Linear,
            min_filter: wgpu::FilterMode::Linear,
            ..Default::default()
        });

        Ok(Self {
            window,
            device,
            queue,
            surface,
            config,
            pipeline,
            bind_group_layout,
            sampler,
            frame_texture: None,
            size: (width, height),
        })
    }

    fn resize(&mut self, width: u32, height: u32) {
        if width == 0 || height == 0 {
            return;
        }
        self.size = (width, height);
        self.config.width = width;
        self.config.height = height;
        self.surface.configure(&self.device, &self.config);
    }

    fn upload_frame(&mut self, frame: &Frame) -> anyhow::Result<()> {
        anyhow::ensure!(
            frame.format == PixelFormat::Bgra8,
            "presenter expects BGRA8 frames, got {:?}",
            frame.format
        );
        anyhow::ensure!(frame.width > 0 && frame.height > 0, "empty frame");

        let needs_new = self
            .frame_texture
            .as_ref()
            .map(|t| t.width != frame.width || t.height != frame.height)
            .unwrap_or(true);

        if needs_new {
            debug!(
                width = frame.width,
                height = frame.height,
                "allocating presentation texture"
            );
            self.frame_texture = Some(self.create_frame_texture(frame.width, frame.height));
        }

        let ft = self
            .frame_texture
            .as_ref()
            .expect("frame texture just ensured");

        let aligned = align_bytes_per_row(frame.width);
        let src_row = frame.stride;
        let row_bytes = (frame.width as usize) * 4;
        anyhow::ensure!(
            src_row >= row_bytes,
            "frame stride {src_row} smaller than width*4 ({row_bytes})"
        );

        if aligned as usize == src_row && frame.pixels.len() >= src_row * frame.height as usize {
            self.queue.write_texture(
                wgpu::TexelCopyTextureInfo {
                    texture: &ft.texture,
                    mip_level: 0,
                    origin: wgpu::Origin3d::ZERO,
                    aspect: wgpu::TextureAspect::All,
                },
                &frame.pixels,
                wgpu::TexelCopyBufferLayout {
                    offset: 0,
                    bytes_per_row: Some(src_row as u32),
                    rows_per_image: Some(frame.height),
                },
                wgpu::Extent3d {
                    width: frame.width,
                    height: frame.height,
                    depth_or_array_layers: 1,
                },
            );
        } else {
            // Repack into wgpu's 256-byte row alignment.
            let mut packed = vec![0u8; aligned as usize * frame.height as usize];
            for y in 0..frame.height as usize {
                let src = y * src_row;
                let dst = y * aligned as usize;
                packed[dst..dst + row_bytes].copy_from_slice(&frame.pixels[src..src + row_bytes]);
            }
            self.queue.write_texture(
                wgpu::TexelCopyTextureInfo {
                    texture: &ft.texture,
                    mip_level: 0,
                    origin: wgpu::Origin3d::ZERO,
                    aspect: wgpu::TextureAspect::All,
                },
                &packed,
                wgpu::TexelCopyBufferLayout {
                    offset: 0,
                    bytes_per_row: Some(aligned),
                    rows_per_image: Some(frame.height),
                },
                wgpu::Extent3d {
                    width: frame.width,
                    height: frame.height,
                    depth_or_array_layers: 1,
                },
            );
        }

        Ok(())
    }

    fn create_frame_texture(&self, width: u32, height: u32) -> FrameTexture {
        let texture = self.device.create_texture(&wgpu::TextureDescriptor {
            label: Some("arv-frame-texture"),
            size: wgpu::Extent3d {
                width,
                height,
                depth_or_array_layers: 1,
            },
            mip_level_count: 1,
            sample_count: 1,
            dimension: wgpu::TextureDimension::D2,
            format: wgpu::TextureFormat::Bgra8Unorm,
            usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
            view_formats: &[],
        });
        let view = texture.create_view(&wgpu::TextureViewDescriptor::default());
        let bind_group = self.device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("arv-frame-bg"),
            layout: &self.bind_group_layout,
            entries: &[
                wgpu::BindGroupEntry {
                    binding: 0,
                    resource: wgpu::BindingResource::TextureView(&view),
                },
                wgpu::BindGroupEntry {
                    binding: 1,
                    resource: wgpu::BindingResource::Sampler(&self.sampler),
                },
            ],
        });
        FrameTexture {
            texture,
            bind_group,
            width,
            height,
        }
    }

    fn render(&mut self) -> anyhow::Result<()> {
        let output = match self.surface.get_current_texture() {
            Ok(frame) => frame,
            Err(wgpu::SurfaceError::Lost | wgpu::SurfaceError::Outdated) => {
                self.resize(self.size.0, self.size.1);
                return Ok(());
            }
            Err(wgpu::SurfaceError::Timeout) => return Ok(()),
            Err(err) => return Err(err.into()),
        };
        let view = output
            .texture
            .create_view(&wgpu::TextureViewDescriptor::default());

        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("arv-encoder"),
            });

        {
            let mut pass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("arv-pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &view,
                    resolve_target: None,
                    ops: wgpu::Operations {
                        load: wgpu::LoadOp::Clear(wgpu::Color::BLACK),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
            });

            if let Some(ft) = self.frame_texture.as_ref() {
                let (vx, vy, vw, vh) =
                    letterbox_viewport(self.size.0, self.size.1, ft.width, ft.height);
                pass.set_viewport(vx, vy, vw, vh, 0.0, 1.0);
                pass.set_pipeline(&self.pipeline);
                pass.set_bind_group(0, &ft.bind_group, &[]);
                pass.draw(0..3, 0..1);
            }
        }

        self.queue.submit(std::iter::once(encoder.finish()));
        self.window.pre_present_notify();
        output.present();
        Ok(())
    }
}

fn align_bytes_per_row(width: u32) -> u32 {
    let unpadded = width * 4;
    let align = wgpu::COPY_BYTES_PER_ROW_ALIGNMENT;
    unpadded.div_ceil(align) * align
}

fn letterbox_viewport(
    window_w: u32,
    window_h: u32,
    content_w: u32,
    content_h: u32,
) -> (f32, f32, f32, f32) {
    let ww = window_w.max(1) as f32;
    let wh = window_h.max(1) as f32;
    let cw = content_w.max(1) as f32;
    let ch = content_h.max(1) as f32;
    let scale = (ww / cw).min(wh / ch);
    let vw = cw * scale;
    let vh = ch * scale;
    let vx = (ww - vw) * 0.5;
    let vy = (wh - vh) * 0.5;
    (vx, vy, vw, vh)
}
