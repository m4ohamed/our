// rust_video_engine/src/lib.rs
// محرك Rust احترافي مستلهم من معمارية FilmCraft (storytold/filmcraft) و EffectCraft (storytold/effectcraft)
// يضم:
// 1. filmcraft-time: نظام التوقيت الصحيح الخالي من الانجراف (Exact Integer Ticks: 254,016,000,000 ticks/sec)
// 2. filmcraft-project::keyframe: حلال Newton-Raphson + Bisection لمنحنيات Cubic Bezier الزمنية و Catmull-Rom
// 3. filmcraft-color: مصفوفات Lumetri Rec.709 وتحويل الفضاء اللوني ITU-R BT.709 Studio-Swing مع 2x2 Chroma Box-Filter
// 4. filmcraft-render-parallel: معالجة دفعات الإطارات بالتوازي عبر كافة أنوية المعالج (std::thread::scope Multi-Core Batching)
// 5. filmcraft-audio-dsp: مازج صوت متعدد المسارات بدقة الـ Tick، وتلاشي Constant-Power Sine، ومحدد ذروة ناعم Soft-Knee Tanh
// 6. filmcraft-avi: تجميع حاوية RIFF/AVI بتداخل إطار بإطار (Frame-Interleaved 00dc + 01wb WAVEFORMATEX PCM)

use std::f64::consts::PI;
use std::fs::File;
use std::io::{BufWriter, Write};
use std::slice;
use std::thread;

/// عدد النبضات الزمنية في الثانية الواحدة كما في `filmcraft-time`
/// يقبل القسمة بدون باقٍ على كافة معدلات الإطارات (23.976, 24, 25, 29.97, 30, 50, 59.94, 60, 120)
/// وكافة ترددات الصوت القياسية (8000, 11025, 16000, 22050, 32000, 44100, 48000, 96000, 192000 Hz)
pub const TICKS_PER_SECOND: i64 = 254_016_000_000;

#[repr(C)]
#[derive(Copy, Clone, Debug)]
pub struct NativeTransform {
    pub x: f64,
    pub y: f64,
    pub scale: f64,
    pub rotation: f64,
    pub opacity: f64,
}

/// إرجاع عدد أنوية المعالج المتاحة للمعالجة المتوازية (Multi-Core Parallelism)
#[no_mangle]
pub extern "C" fn rust_get_hardware_concurrency() -> u32 {
    thread::available_parallelism()
        .map(|n| n.get() as u32)
        .unwrap_or(4)
        .max(1)
}

/// تحويل الثواني إلى نبضات صحيحة (Exact Integer Ticks) لمنع أي انجراف في الفريمات أو العينات الصوتية
#[no_mangle]
pub extern "C" fn rust_seconds_to_ticks(seconds: f64) -> i64 {
    (seconds * (TICKS_PER_SECOND as f64)).round() as i64
}

/// تحويل النبضات الصحيحة إلى ثوانٍ
#[no_mangle]
pub extern "C" fn rust_ticks_to_seconds(ticks: i64) -> f64 {
    (ticks as f64) / (TICKS_PER_SECOND as f64)
}

/// تحويل النبضات الزمنية (Ticks) إلى فهرس عينة صوتية دقيق (Exact Sample Frame Index)
#[no_mangle]
pub extern "C" fn rust_ticks_to_audio_sample(ticks: i64, sample_rate: u32) -> i64 {
    if ticks <= 0 || sample_rate == 0 {
        return 0;
    }
    ((ticks as i128 * sample_rate as i128) / (TICKS_PER_SECOND as i128)) as i64
}

/// تقييم متعدد الحدود التكعيبي لبيزييه عند المعامل u ضمن [0, 1] مع P0 = 0 و P3 = 1
#[inline]
fn sample_bezier_axis(c1: f64, c2: f64, u: f64) -> f64 {
    let inv = 1.0 - u;
    3.0 * inv * inv * u * c1 + 3.0 * inv * u * u * c2 + u * u * u
}

/// مشتقة متعدد الحدود التكعيبي لبيزييه dB/du عند المعامل u
#[inline]
fn sample_bezier_derivative(c1: f64, c2: f64, u: f64) -> f64 {
    let inv = 1.0 - u;
    3.0 * inv * inv * c1 + 6.0 * inv * u * (c2 - c1) + 3.0 * u * u * (1.0 - c2)
}

/// حل معادلة الزمن x(u) = t باستخدام خوارزمية Newton-Raphson مع بديل التنصيف (Bisection)
/// كما في `filmcraft-project::keyframe` للحصول على قيمة y(u) الدقيقة زمنياً
#[no_mangle]
pub extern "C" fn rust_solve_cubic_bezier_2d(
    x1: f64,
    y1: f64,
    x2: f64,
    y2: f64,
    t: f64,
) -> f64 {
    let clamped_t = t.clamp(0.0, 1.0);
    if clamped_t <= 0.0 {
        return 0.0;
    }
    if clamped_t >= 1.0 {
        return 1.0;
    }

    let cx1 = x1.clamp(0.0, 1.0);
    let cx2 = x2.clamp(0.0, 1.0);
    if (cx1 - y1).abs() < 1e-7 && (cx2 - y2).abs() < 1e-7 {
        return clamped_t;
    }

    // 1. 6 تكرارات سريعة بطريقة Newton-Raphson
    let mut u = clamped_t;
    for _ in 0..6 {
        let err = sample_bezier_axis(cx1, cx2, u) - clamped_t;
        if err.abs() < 1e-7 {
            return sample_bezier_axis(y1, y2, u);
        }
        let deriv = sample_bezier_derivative(cx1, cx2, u);
        if deriv.abs() < 1e-6 {
            break;
        }
        u = (u - err / deriv).clamp(0.0, 1.0);
    }

    // 2. بديل التنصيف المضمون (Bisection) عند المنحنيات الحادة
    let mut lo = 0.0_f64;
    let mut hi = 1.0_f64;
    u = clamped_t;
    for _ in 0..10 {
        let x_val = sample_bezier_axis(cx1, cx2, u);
        if (x_val - clamped_t).abs() < 1e-7 {
            break;
        }
        if clamped_t > x_val {
            lo = u;
        } else {
            hi = u;
        }
        u = 0.5 * (lo + hi);
    }

    sample_bezier_axis(y1, y2, u)
}

/// استيفاء Cubic Bezier أحادي البعد مع نقاط تحكم مخصصة
#[no_mangle]
pub extern "C" fn rust_cubic_bezier_eval(p0: f64, p1: f64, p2: f64, p3: f64, t: f64) -> f64 {
    let u = t.clamp(0.0, 1.0);
    let inv = 1.0 - u;
    let inv2 = inv * inv;
    let inv3 = inv2 * inv;
    let u2 = u * u;
    let u3 = u2 * u;
    inv3 * p0 + 3.0 * inv2 * u * p1 + 3.0 * inv * u2 * p2 + u3 * p3
}

/// تطبيق منحنى الحركة (Easing) في Rust بسرعة C-ABI مع حل Newton-Raphson الزمني
/// easing_type: 0 = Linear, 1 = EaseIn, 2 = EaseOut, 3 = EaseInOut, 4 = ElasticOut, 5 = Hold, 6 = AutoBezier
#[no_mangle]
pub extern "C" fn rust_apply_easing(t: f64, easing_type: i32) -> f64 {
    let clamped = t.clamp(0.0, 1.0);
    match easing_type {
        1 => rust_solve_cubic_bezier_2d(0.42, 0.0, 1.0, 1.0, clamped),
        2 => rust_solve_cubic_bezier_2d(0.0, 0.0, 0.58, 1.0, clamped),
        3 => rust_solve_cubic_bezier_2d(0.42, 0.0, 0.58, 1.0, clamped),
        4 => {
            if clamped == 0.0 || clamped == 1.0 {
                clamped
            } else {
                let c4 = (2.0 * PI) / 3.0;
                2.0_f64.powf(-10.0 * clamped) * ((clamped * 10.0 - 0.75) * c4).sin() + 1.0
            }
        }
        5 => {
            if clamped < 1.0 { 0.0 } else { 1.0 }
        }
        6 => rust_solve_cubic_bezier_2d(0.25, 0.1, 0.25, 1.0, clamped),
        _ => clamped,
    }
}

/// استيفاء Catmull-Rom / Auto-Bezier السلس عبر 4 نقاط متتالية (كما في مسارات الحركة في EffectCraft)
#[no_mangle]
pub extern "C" fn rust_catmull_rom_spline(p0: f64, p1: f64, p2: f64, p3: f64, t: f64) -> f64 {
    let t = t.clamp(0.0, 1.0);
    let t2 = t * t;
    let t3 = t2 * t;
    0.5 * ((2.0 * p1)
        + (-p0 + p2) * t
        + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
        + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
}

/// استيفاء (Interpolation) بين نقطتي Keyframe عبر FFI
#[no_mangle]
pub extern "C" fn rust_interpolate_keyframes(
    t: f64,
    easing_type: i32,
    x0: f64,
    y0: f64,
    s0: f64,
    r0: f64,
    o0: f64,
    x1: f64,
    y1: f64,
    s1: f64,
    r1: f64,
    o1: f64,
) -> NativeTransform {
    let progress = rust_apply_easing(t, easing_type);
    NativeTransform {
        x: x0 + (x1 - x0) * progress,
        y: y0 + (y1 - y0) * progress,
        scale: (s0 + (s1 - s0) * progress).clamp(0.1, 5.0),
        rotation: r0 + (r1 - r0) * progress,
        opacity: (o0 + (o1 - o0) * progress).clamp(0.0, 1.0),
    }
}

#[inline]
fn compute_lumetri_matrix_array(
    exposure: f64,
    contrast: f64,
    saturation: f64,
    temperature: f64,
    faded_film: f64,
) -> [f64; 20] {
    let gain = 2.0_f64.powf(exposure.clamp(-2.0, 2.0));
    let c = (1.0 + contrast.clamp(-0.8, 1.5)).max(0.1);
    let s = (1.0 + saturation.clamp(-1.0, 1.5)).max(0.0);
    let temp = temperature.clamp(-1.0, 1.0) * 30.0;
    let fade = faded_film.clamp(0.0, 0.5) * 45.0;

    // معاملات الإضاءة القياسية ITU-R BT.709 كما في `filmcraft-color`
    let lum_r = 0.2126;
    let lum_g = 0.7152;
    let lum_b = 0.0722;

    let sr = (1.0 - s) * lum_r;
    let sg = (1.0 - s) * lum_g;
    let sb = (1.0 - s) * lum_b;

    let scale = gain * c;
    let offset = (1.0 - c) * 128.0 + fade;

    [
        scale * (sr + s),
        scale * sg,
        scale * sb,
        0.0,
        offset + temp,
        scale * sr,
        scale * (sg + s),
        scale * sb,
        0.0,
        offset,
        scale * sr,
        scale * sg,
        scale * (sb + s),
        0.0,
        offset - temp,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
    ]
}

/// حساب مصفوفة تصحيح الألوان 4x5 (20 عنصراً) بأسلوب Lumetri Color في `filmcraft-color`
/// تشمل: Exposure, Contrast, Saturation, Temperature (Warm/Cool), Faded Film
#[no_mangle]
pub unsafe extern "C" fn rust_compute_lumetri_matrix(
    exposure: f64,
    contrast: f64,
    saturation: f64,
    temperature: f64,
    faded_film: f64,
    out_matrix_20: *mut f64,
) {
    if out_matrix_20.is_null() {
        return;
    }
    let out = slice::from_raw_parts_mut(out_matrix_20, 20);
    let m = compute_lumetri_matrix_array(exposure, contrast, saturation, temperature, faded_film);
    out.copy_from_slice(&m);
}

/// دمج بكسلات إطارين (RGBA8888) في الذاكرة لتطبيق انتقالات الفيديو بسرعة فائقة
#[no_mangle]
pub unsafe extern "C" fn rust_blend_rgba_frames(
    frame_a: *const u8,
    frame_b: *const u8,
    output: *mut u8,
    length: usize,
    progress: f64,
) {
    if frame_a.is_null() || frame_b.is_null() || output.is_null() {
        return;
    }
    let alpha = progress.clamp(0.0, 1.0);
    let inv_alpha = 1.0 - alpha;

    let slice_a = slice::from_raw_parts(frame_a, length);
    let slice_b = slice::from_raw_parts(frame_b, length);
    let slice_out = slice::from_raw_parts_mut(output, length);

    for i in 0..length {
        let va = slice_a[i] as f64;
        let vb = slice_b[i] as f64;
        slice_out[i] = (va * inv_alpha + vb * alpha).round().clamp(0.0, 255.0) as u8;
    }
}

/// تحويل إطار RGBA8888 مفرد إلى NV12 بمعيار ITU-R BT.709 Studio-Swing مع فلتر 2x2 للكروما (آمن للاستدعاء المتوازي)
#[inline]
fn convert_single_rgba_to_bt709_nv12(rgba: &[u8], nv12: &mut [u8], w: usize, h: usize) {
    let y_size = w * h;
    let (y_plane, uv_plane) = nv12.split_at_mut(y_size);

    for y in 0..h {
        let src_row = y * w * 4;
        let dst_row = y * w;
        for x in 0..w {
            let px = src_row + x * 4;
            let r = rgba[px] as i32;
            let g = rgba[px + 1] as i32;
            let b = rgba[px + 2] as i32;
            y_plane[dst_row + x] = (((47 * r + 157 * g + 16 * b + 128) >> 8) + 16).clamp(16, 235) as u8;
        }
    }

    let half_h = h / 2;
    let half_w = w / 2;
    for uy in 0..half_h {
        let y0 = uy * 2;
        let y1 = (y0 + 1).min(h - 1);
        let row0 = y0 * w * 4;
        let row1 = y1 * w * 4;
        let uv_dst_row = uy * w;

        for ux in 0..half_w {
            let x0 = ux * 2;
            let x1 = (x0 + 1).min(w - 1);

            let p00 = row0 + x0 * 4;
            let p01 = row0 + x1 * 4;
            let p10 = row1 + x0 * 4;
            let p11 = row1 + x1 * 4;

            let r_avg = (rgba[p00] as i32
                + rgba[p01] as i32
                + rgba[p10] as i32
                + rgba[p11] as i32
                + 2)
                >> 2;
            let g_avg = (rgba[p00 + 1] as i32
                + rgba[p01 + 1] as i32
                + rgba[p10 + 1] as i32
                + rgba[p11 + 1] as i32
                + 2)
                >> 2;
            let b_avg = (rgba[p00 + 2] as i32
                + rgba[p01 + 2] as i32
                + rgba[p10 + 2] as i32
                + rgba[p11 + 2] as i32
                + 2)
                >> 2;

            let u_val =
                (((-25 * r_avg - 87 * g_avg + 112 * b_avg + 128) >> 8) + 128).clamp(16, 240) as u8;
            let v_val =
                (((112 * r_avg - 102 * g_avg - 10 * b_avg + 128) >> 8) + 128).clamp(16, 240) as u8;

            let dst_idx = uv_dst_row + ux * 2;
            if dst_idx + 1 < uv_plane.len() {
                uv_plane[dst_idx] = u_val;
                uv_plane[dst_idx + 1] = v_val;
            }
        }
    }
}

/// تحويل إطار RGBA8888 إلى فضاء ITU-R BT.709 Studio-Swing YUV420 مع فلتر 2x2 للكروما ودعم Strides مخصصة
/// يتوافق مع معيار HDTV (Y: 16..235, Cb/Cr: 16..240) لمنع أي انحراف لوني عند العرض في معرض الهاتف
#[no_mangle]
pub unsafe extern "C" fn rust_rgba_to_bt709_yuv420_strided(
    rgba_ptr: *const u8,
    y_out_ptr: *mut u8,
    u_out_ptr: *mut u8,
    v_out_ptr: *mut u8,
    width: u32,
    height: u32,
    y_row_stride: u32,
    uv_row_stride: u32,
    uv_pixel_stride: u32,
) -> i32 {
    if rgba_ptr.is_null()
        || y_out_ptr.is_null()
        || u_out_ptr.is_null()
        || v_out_ptr.is_null()
        || width == 0
        || height == 0
    {
        return -1;
    }

    let w = width as usize;
    let h = height as usize;
    let y_stride = (y_row_stride as usize).max(w);
    let uv_stride = (uv_row_stride as usize).max(w / 2);
    let uv_px_stride = (uv_pixel_stride as usize).max(1);

    let rgba = slice::from_raw_parts(rgba_ptr, w * h * 4);
    let y_plane = slice::from_raw_parts_mut(y_out_ptr, y_stride * h);
    let uv_rows = (h + 1) / 2;
    let uv_plane_len = uv_stride * uv_rows + uv_px_stride;
    let u_plane = slice::from_raw_parts_mut(u_out_ptr, uv_plane_len);
    let v_plane = slice::from_raw_parts_mut(v_out_ptr, uv_plane_len);

    // 1. حساب مستوى الإضاءة (Luma Y) لكل بكسل بمعاملات ITU-R BT.709 Studio-Swing:
    // Y = ((47 * R + 157 * G + 16 * B + 128) >> 8) + 16
    for y in 0..h {
        let src_row = y * w * 4;
        let dst_row = y * y_stride;
        for x in 0..w {
            let px = src_row + x * 4;
            let r = rgba[px] as i32;
            let g = rgba[px + 1] as i32;
            let b = rgba[px + 2] as i32;
            let y_val = (((47 * r + 157 * g + 16 * b + 128) >> 8) + 16).clamp(16, 235) as u8;
            y_plane[dst_row + x] = y_val;
        }
    }

    // 2. حساب الكروما (Cb/Cr) عبر متوسط مربع 2x2 بكسل (2x2 Box-Filter) لمنع التعرج اللوني على حواف النصوص
    // Cb = ((-25 * R - 87 * G + 112 * B + 128) >> 8) + 128
    // Cr = ((112 * R - 102 * G - 10 * B + 128) >> 8) + 128
    let half_h = h / 2;
    let half_w = w / 2;
    for uy in 0..half_h {
        let y0 = uy * 2;
        let y1 = (y0 + 1).min(h - 1);
        let row0 = y0 * w * 4;
        let row1 = y1 * w * 4;
        let uv_dst_row = uy * uv_stride;

        for ux in 0..half_w {
            let x0 = ux * 2;
            let x1 = (x0 + 1).min(w - 1);

            let p00 = row0 + x0 * 4;
            let p01 = row0 + x1 * 4;
            let p10 = row1 + x0 * 4;
            let p11 = row1 + x1 * 4;

            let r_avg = (rgba[p00] as i32
                + rgba[p01] as i32
                + rgba[p10] as i32
                + rgba[p11] as i32
                + 2)
                >> 2;
            let g_avg = (rgba[p00 + 1] as i32
                + rgba[p01 + 1] as i32
                + rgba[p10 + 1] as i32
                + rgba[p11 + 1] as i32
                + 2)
                >> 2;
            let b_avg = (rgba[p00 + 2] as i32
                + rgba[p01 + 2] as i32
                + rgba[p10 + 2] as i32
                + rgba[p11 + 2] as i32
                + 2)
                >> 2;

            let u_val =
                (((-25 * r_avg - 87 * g_avg + 112 * b_avg + 128) >> 8) + 128).clamp(16, 240) as u8;
            let v_val =
                (((112 * r_avg - 102 * g_avg - 10 * b_avg + 128) >> 8) + 128).clamp(16, 240) as u8;

            let dst_idx = uv_dst_row + ux * uv_px_stride;
            u_plane[dst_idx] = u_val;
            v_plane[dst_idx] = v_val;
        }
    }

    0
}

/// تحويل إطار RGBA8888 إلى فضاء YUV420 Semi-Planar (NV12) بمعيار ITU-R BT.709 وفلتر 2x2 للكروما
#[no_mangle]
pub unsafe extern "C" fn rust_rgba_to_nv12(
    rgba_ptr: *const u8,
    nv12_out_ptr: *mut u8,
    width: u32,
    height: u32,
) -> i32 {
    if rgba_ptr.is_null() || nv12_out_ptr.is_null() || width == 0 || height == 0 {
        return -1;
    }
    let y_size = (width as usize) * (height as usize);
    let y_ptr = nv12_out_ptr;
    let u_ptr = nv12_out_ptr.add(y_size);
    let v_ptr = nv12_out_ptr.add(y_size + 1);

    rust_rgba_to_bt709_yuv420_strided(
        rgba_ptr,
        y_ptr,
        u_ptr,
        v_ptr,
        width,
        height,
        width,
        width,
        2,
    )
}

/// معالجة دفعة كاملة من إطارات RGBA8888 بالتوازي عبر جميع أنوية المعالج (Multi-Core Scoped Threads)
/// لتطبيق مصفوفة ألوان Lumetri والتظليل السينمائي (Vignette) في وقت واحد على عدة إطارات
#[no_mangle]
pub unsafe extern "C" fn rust_process_rgba_batch_lumetri(
    rgba_batch_ptr: *mut u8,
    num_frames: usize,
    width: u32,
    height: u32,
    exposure: f64,
    contrast: f64,
    saturation: f64,
    temperature: f64,
    faded_film: f64,
    vignette: f64,
) -> i32 {
    if rgba_batch_ptr.is_null() || num_frames == 0 || width == 0 || height == 0 {
        return -1;
    }
    let w = width as usize;
    let h = height as usize;
    let frame_bytes = w.saturating_mul(h).saturating_mul(4);
    let total_bytes = frame_bytes.saturating_mul(num_frames);
    if frame_bytes == 0 || total_bytes == 0 {
        return -2;
    }

    let m = compute_lumetri_matrix_array(exposure, contrast, saturation, temperature, faded_film);
    let vig = vignette.clamp(0.0, 0.85);
    let batch_slice = slice::from_raw_parts_mut(rgba_batch_ptr, total_bytes);

    let max_threads = thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4)
        .clamp(1, 8);
    let frames_per_chunk = (num_frames + max_threads - 1) / max_threads;
    let bytes_per_chunk = frames_per_chunk * frame_bytes;

    thread::scope(|s| {
        for chunk in batch_slice.chunks_mut(bytes_per_chunk) {
            s.spawn(move || {
                let cx = (w as f64) * 0.5;
                let cy = (h as f64) * 0.5;
                let inv_max_dist = 1.0 / (cx * cx + cy * cy).sqrt().max(1.0);

                for frame in chunk.chunks_exact_mut(frame_bytes) {
                    for y in 0..h {
                        let dy = (y as f64) - cy;
                        let row_off = y * w * 4;
                        for x in 0..w {
                            let idx = row_off + x * 4;
                            let r = frame[idx] as f64;
                            let g = frame[idx + 1] as f64;
                            let b = frame[idx + 2] as f64;

                            let mut nr = m[0] * r + m[1] * g + m[2] * b + m[4];
                            let mut ng = m[5] * r + m[6] * g + m[7] * b + m[9];
                            let mut nb = m[10] * r + m[11] * g + m[12] * b + m[14];

                            if vig > 0.01 {
                                let dx = (x as f64) - cx;
                                let dist = (dx * dx + dy * dy).sqrt() * inv_max_dist;
                                if dist > 0.45 {
                                    let factor =
                                        1.0 - vig * ((dist - 0.45) / 0.55).clamp(0.0, 1.0);
                                    nr *= factor;
                                    ng *= factor;
                                    nb *= factor;
                                }
                            }

                            frame[idx] = nr.round().clamp(0.0, 255.0) as u8;
                            frame[idx + 1] = ng.round().clamp(0.0, 255.0) as u8;
                            frame[idx + 2] = nb.round().clamp(0.0, 255.0) as u8;
                        }
                    }
                }
            });
        }
    });

    0
}

/// تحويل دفعة إطارات RGBA8888 بالتوازي عبر جميع أنوية المعالج (Multi-Core Scoped Threads)
/// إلى فضاء ITU-R BT.709 Studio-Swing NV12 مع فلتر 2x2 Box-Filter للكروما
#[no_mangle]
pub unsafe extern "C" fn rust_rgba_batch_to_bt709_nv12(
    rgba_batch_ptr: *const u8,
    nv12_batch_out_ptr: *mut u8,
    num_frames: usize,
    width: u32,
    height: u32,
) -> i32 {
    if rgba_batch_ptr.is_null()
        || nv12_batch_out_ptr.is_null()
        || num_frames == 0
        || width == 0
        || height == 0
    {
        return -1;
    }

    let w = width as usize;
    let h = height as usize;
    let rgba_frame_size = w.saturating_mul(h).saturating_mul(4);
    let nv12_frame_size = (w.saturating_mul(h).saturating_mul(3)) / 2;
    if rgba_frame_size == 0 || nv12_frame_size == 0 {
        return -2;
    }

    let rgba_all = slice::from_raw_parts(rgba_batch_ptr, rgba_frame_size * num_frames);
    let nv12_all = slice::from_raw_parts_mut(nv12_batch_out_ptr, nv12_frame_size * num_frames);

    let max_threads = thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4)
        .clamp(1, 8);
    let frames_per_worker = (num_frames + max_threads - 1) / max_threads;

    thread::scope(|s| {
        for (rgba_chunk, nv12_chunk) in rgba_all
            .chunks(frames_per_worker * rgba_frame_size)
            .zip(nv12_all.chunks_mut(frames_per_worker * nv12_frame_size))
        {
            s.spawn(move || {
                for (src_frame, dst_frame) in rgba_chunk
                    .chunks_exact(rgba_frame_size)
                    .zip(nv12_chunk.chunks_exact_mut(nv12_frame_size))
                {
                    convert_single_rgba_to_bt709_nv12(src_frame, dst_frame, w, h);
                }
            });
        }
    });

    0
}

/// محدد ذروة صوتي ناعم (Soft-Knee Tanh True-Peak Limiter) كما في `filmcraft-audio-dsp`
/// يمنع التشوه الرقمي الحاد (Hard Clipping) عند جمع مسارات صوتية متعددة
#[inline]
fn soft_knee_true_peak_limit(sample: f64) -> i16 {
    const KNEE_START: f64 = 28_000.0;
    const MAX_CEILING: f64 = 32_700.0;
    const HEADROOM: f64 = MAX_CEILING - KNEE_START;

    let abs_s = sample.abs();
    if abs_s <= KNEE_START {
        return sample.round() as i16;
    }
    let sign = sample.signum();
    let excess = (abs_s - KNEE_START) / HEADROOM;
    let compressed = KNEE_START + HEADROOM * excess.tanh();
    (sign * compressed).round().clamp(-32767.0, 32767.0) as i16
}

/// دمج مؤثر صوتي (Overlay Track PCM 16-bit LE) فوق المسار الصوتي الرئيسي عند زمن بداية محدد بالثواني
/// يستخدم حساب الـ Ticks الدقيق (`TICKS_PER_SECOND`) ومحدد الذروة الناعم
#[no_mangle]
pub unsafe extern "C" fn rust_mix_pcm16_overlay(
    master_pcm_ptr: *mut u8,
    master_byte_len: usize,
    overlay_pcm_ptr: *const u8,
    overlay_byte_len: usize,
    sample_rate: u32,
    channels: u16,
    start_time_seconds: f64,
    overlay_volume: f64,
) -> i32 {
    if master_pcm_ptr.is_null()
        || overlay_pcm_ptr.is_null()
        || master_byte_len < 2
        || overlay_byte_len < 2
        || sample_rate == 0
        || channels == 0
    {
        return -1;
    }

    let master = slice::from_raw_parts_mut(master_pcm_ptr, master_byte_len);
    let overlay = slice::from_raw_parts(overlay_pcm_ptr, overlay_byte_len);

    let start_ticks = rust_seconds_to_ticks(start_time_seconds.max(0.0));
    let start_frame = rust_ticks_to_audio_sample(start_ticks, sample_rate) as usize;
    let start_byte = start_frame.saturating_mul(channels as usize).saturating_mul(2);

    if start_byte >= master_byte_len {
        return 0;
    }

    let gain = overlay_volume.clamp(0.0, 2.0);
    let available_bytes = (master_byte_len - start_byte).min(overlay_byte_len) & !1;
    let num_samples = available_bytes / 2;

    for i in 0..num_samples {
        let m_idx = start_byte + i * 2;
        let o_idx = i * 2;
        let m_sample = i16::from_le_bytes([master[m_idx], master[m_idx + 1]]) as f64;
        let o_sample = i16::from_le_bytes([overlay[o_idx], overlay[o_idx + 1]]) as f64;

        let mixed = m_sample + o_sample * gain;
        let limited = soft_knee_true_peak_limit(mixed);
        let bytes = limited.to_le_bytes();
        master[m_idx] = bytes[0];
        master[m_idx + 1] = bytes[1];
    }

    0
}

/// معالجة عينات الصوت PCM 16-bit LE بأسلوب `filmcraft-audio-dsp`
/// (تطبيق مستوى الصوت، تلاشي الدخول والخروج Constant-Power Sine Fade، ومحدد الذروة Soft-Knee True-Peak Limiter)
#[no_mangle]
pub unsafe extern "C" fn rust_process_pcm16_audio(
    pcm_bytes_ptr: *mut u8,
    pcm_byte_len: usize,
    sample_rate: u32,
    channels: u16,
    volume: f64,
    fade_in: i32,
    fade_out: i32,
) -> i32 {
    if pcm_bytes_ptr.is_null() || pcm_byte_len < 2 || sample_rate == 0 || channels == 0 {
        return -1;
    }
    let pcm = slice::from_raw_parts_mut(pcm_bytes_ptr, pcm_byte_len);
    let bytes_per_sec = (sample_rate as usize) * (channels as usize) * 2;
    if bytes_per_sec == 0 {
        return -2;
    }

    let total_samples = pcm_byte_len / 2;
    let total_seconds = (pcm_byte_len as f64) / (bytes_per_sec as f64);
    let fade_window = 1.2_f64;
    let base_gain = volume.clamp(0.0, 1.5);

    for i in 0..total_samples {
        let byte_idx = i * 2;
        let current_sec = (byte_idx as f64) / (bytes_per_sec as f64);
        let mut gain = base_gain;

        if fade_in != 0 && current_sec < fade_window {
            let ratio = (current_sec / fade_window).clamp(0.0, 1.0);
            gain *= (ratio * PI * 0.5).sin();
        }
        if fade_out != 0 && (total_seconds - current_sec) < fade_window {
            let ratio = ((total_seconds - current_sec) / fade_window).clamp(0.0, 1.0);
            gain *= (ratio * PI * 0.5).sin();
        }

        let sample = i16::from_le_bytes([pcm[byte_idx], pcm[byte_idx + 1]]) as f64;
        let limited = soft_knee_true_peak_limit(sample * gain);
        let out_bytes = limited.to_le_bytes();
        pcm[byte_idx] = out_bytes[0];
        pcm[byte_idx + 1] = out_bytes[1];
    }
    0
}

/// تجميع سلسلة إطارات مضغوطة (PNG / MJPG) داخل ملف فيديو قياسي RIFF AVI مباشرة عبر Rust
#[no_mangle]
pub unsafe extern "C" fn rust_mux_frames_to_avi(
    output_path_ptr: *const u8,
    output_path_len: usize,
    frames_concat_ptr: *const u8,
    frame_sizes_ptr: *const u32,
    num_frames: usize,
    width: u32,
    height: u32,
    fps: u32,
) -> i32 {
    rust_mux_frames_and_pcm_to_avi(
        output_path_ptr,
        output_path_len,
        frames_concat_ptr,
        frame_sizes_ptr,
        num_frames,
        width,
        height,
        fps,
        std::ptr::null(),
        0,
        44100,
        2,
    )
}

/// تجميع سلسلة إطارات الفيديو (`00dc`) مع مسار الصوت (`01wb` PCM 16-bit) بتداخل إطار بإطار (Frame-Interleaved)
/// داخل حاوية RIFF AVI قياسية كما في `filmcraft-avi`
#[no_mangle]
pub unsafe extern "C" fn rust_mux_frames_and_pcm_to_avi(
    output_path_ptr: *const u8,
    output_path_len: usize,
    frames_concat_ptr: *const u8,
    frame_sizes_ptr: *const u32,
    num_frames: usize,
    width: u32,
    height: u32,
    fps: u32,
    pcm_data_ptr: *const u8,
    pcm_byte_len: usize,
    sample_rate: u32,
    channels: u16,
) -> i32 {
    if output_path_ptr.is_null() || frames_concat_ptr.is_null() || frame_sizes_ptr.is_null() {
        return -1;
    }
    let path_bytes = slice::from_raw_parts(output_path_ptr, output_path_len);
    let path_str = match std::str::from_utf8(path_bytes) {
        Ok(s) => s,
        Err(_) => return -2,
    };
    let sizes = slice::from_raw_parts(frame_sizes_ptr, num_frames);
    let total_bytes: usize = sizes.iter().map(|&s| s as usize).sum();
    let all_frames = slice::from_raw_parts(frames_concat_ptr, total_bytes);

    let audio_opt = if !pcm_data_ptr.is_null()
        && pcm_byte_len > 0
        && sample_rate > 0
        && channels > 0
    {
        Some((
            slice::from_raw_parts(pcm_data_ptr, pcm_byte_len),
            sample_rate,
            channels,
        ))
    } else {
        None
    };

    match write_avi_container(path_str, all_frames, sizes, width, height, fps, audio_opt) {
        Ok(_) => 0,
        Err(_) => -3,
    }
}

fn write_avi_container(
    path: &str,
    all_frames: &[u8],
    sizes: &[u32],
    width: u32,
    height: u32,
    fps: u32,
    audio_pcm: Option<(&[u8], u32, u16)>,
) -> std::io::Result<()> {
    let file = File::create(path)?;
    let mut f = BufWriter::with_capacity(256 * 1024, file);
    let num_frames = sizes.len() as u32;
    let safe_fps = if fps > 0 { fps } else { 15 };
    let usec_per_frame = 1_000_000 / safe_fps;
    let frame_buffer_size = width.saturating_mul(height).saturating_mul(4);
    let max_bytes_per_sec = frame_buffer_size.saturating_mul(safe_fps);

    // تقسيم الصوت إلى شرائح متداخلة مع كل إطار فيديو (1:1 Frame-Interleaved 00dc + 01wb)
    let mut audio_slices: Vec<&[u8]> = Vec::new();
    if let Some((pcm_bytes, sample_rate, channels)) = audio_pcm {
        let block_align = (channels.max(1) as usize) * 2;
        let aligned_total = (pcm_bytes.len() / block_align) * block_align;
        let valid_pcm = &pcm_bytes[..aligned_total];

        if !valid_pcm.is_empty() && !sizes.is_empty() {
            let avg_bytes_per_sec = (sample_rate as usize) * block_align;
            let raw_bytes_per_frame = avg_bytes_per_sec / (safe_fps as usize).max(1);
            let aligned_bytes_per_frame =
                ((raw_bytes_per_frame + block_align - 1) / block_align).max(1) * block_align;

            let mut aud_cursor = 0usize;
            for i in 0..sizes.len() {
                if aud_cursor >= valid_pcm.len() {
                    break;
                }
                let end = if i + 1 == sizes.len() {
                    valid_pcm.len()
                } else {
                    (aud_cursor + aligned_bytes_per_frame).min(valid_pcm.len())
                };
                if end > aud_cursor {
                    audio_slices.push(&valid_pcm[aud_cursor..end]);
                    aud_cursor = end;
                }
            }
        }
    }

    let has_audio = !audio_slices.is_empty() && audio_pcm.is_some();
    let num_streams: u32 = if has_audio { 2 } else { 1 };
    let audio_strl_list_total: u32 = if has_audio { 8 + 92 } else { 0 };
    let hdrl_size: u32 = 192 + audio_strl_list_total;

    let mut movi_payload_bytes: u32 = 4; // "movi"
    for &sz in sizes {
        movi_payload_bytes = movi_payload_bytes
            .saturating_add(8)
            .saturating_add(sz)
            .saturating_add(sz % 2);
    }
    for slice_aud in &audio_slices {
        let aud_sz = slice_aud.len() as u32;
        movi_payload_bytes = movi_payload_bytes
            .saturating_add(8)
            .saturating_add(aud_sz)
            .saturating_add(aud_sz % 2);
    }

    let total_index_entries = sizes.len() + audio_slices.len();
    let idx1_bytes = (total_index_entries as u32).saturating_mul(16);
    let riff_size = 4u32
        .saturating_add(8 + hdrl_size)
        .saturating_add(8 + movi_payload_bytes)
        .saturating_add(8 + idx1_bytes);

    f.write_all(b"RIFF")?;
    f.write_all(&riff_size.to_le_bytes())?;
    f.write_all(b"AVI ")?;

    f.write_all(b"LIST")?;
    f.write_all(&hdrl_size.to_le_bytes())?;
    f.write_all(b"hdrl")?;

    f.write_all(b"avih")?;
    f.write_all(&56u32.to_le_bytes())?;
    f.write_all(&usec_per_frame.to_le_bytes())?;
    f.write_all(&max_bytes_per_sec.to_le_bytes())?;
    f.write_all(&0u32.to_le_bytes())?;
    let avi_flags: u32 = if has_audio { 0x110 } else { 0x10 };
    f.write_all(&avi_flags.to_le_bytes())?;
    f.write_all(&num_frames.to_le_bytes())?;
    f.write_all(&0u32.to_le_bytes())?;
    f.write_all(&num_streams.to_le_bytes())?;
    f.write_all(&frame_buffer_size.to_le_bytes())?;
    f.write_all(&width.to_le_bytes())?;
    f.write_all(&height.to_le_bytes())?;
    f.write_all(&[0u8; 16])?;

    // Stream 0: Video (vids / MPNG)
    f.write_all(b"LIST")?;
    f.write_all(&116u32.to_le_bytes())?;
    f.write_all(b"strl")?;

    f.write_all(b"strh")?;
    f.write_all(&56u32.to_le_bytes())?;
    f.write_all(b"vids")?;
    f.write_all(b"MPNG")?;
    f.write_all(&0u32.to_le_bytes())?;
    f.write_all(&0u16.to_le_bytes())?;
    f.write_all(&0u16.to_le_bytes())?;
    f.write_all(&0u32.to_le_bytes())?;
    f.write_all(&1u32.to_le_bytes())?;
    f.write_all(&safe_fps.to_le_bytes())?;
    f.write_all(&0u32.to_le_bytes())?;
    f.write_all(&num_frames.to_le_bytes())?;
    f.write_all(&frame_buffer_size.to_le_bytes())?;
    f.write_all(&0xFFFFFFFFu32.to_le_bytes())?;
    f.write_all(&0u32.to_le_bytes())?;
    f.write_all(&0u16.to_le_bytes())?;
    f.write_all(&0u16.to_le_bytes())?;
    f.write_all(&(width as u16).to_le_bytes())?;
    f.write_all(&(height as u16).to_le_bytes())?;

    f.write_all(b"strf")?;
    f.write_all(&40u32.to_le_bytes())?;
    f.write_all(&40u32.to_le_bytes())?;
    f.write_all(&width.to_le_bytes())?;
    f.write_all(&height.to_le_bytes())?;
    f.write_all(&1u16.to_le_bytes())?;
    f.write_all(&32u16.to_le_bytes())?;
    f.write_all(b"MPNG")?;
    f.write_all(&frame_buffer_size.to_le_bytes())?;
    f.write_all(&[0u8; 16])?;

    // Stream 1: Audio (auds / WAVE_FORMAT_PCM 0x0001)
    if has_audio {
        if let Some((_, sample_rate, channels)) = audio_pcm {
            let block_align: u16 = channels.saturating_mul(2);
            let avg_bytes_per_sec: u32 = sample_rate.saturating_mul(block_align as u32);
            let total_aud_bytes: u32 = audio_slices.iter().map(|s| s.len() as u32).sum();
            let total_samples: u32 = total_aud_bytes / (block_align.max(1) as u32);

            f.write_all(b"LIST")?;
            f.write_all(&92u32.to_le_bytes())?;
            f.write_all(b"strl")?;

            f.write_all(b"strh")?;
            f.write_all(&56u32.to_le_bytes())?;
            f.write_all(b"auds")?;
            f.write_all(&1u32.to_le_bytes())?;
            f.write_all(&0u32.to_le_bytes())?;
            f.write_all(&0u16.to_le_bytes())?;
            f.write_all(&0u16.to_le_bytes())?;
            f.write_all(&0u32.to_le_bytes())?;
            f.write_all(&(block_align as u32).to_le_bytes())?;
            f.write_all(&avg_bytes_per_sec.to_le_bytes())?;
            f.write_all(&0u32.to_le_bytes())?;
            f.write_all(&total_samples.to_le_bytes())?;
            f.write_all(&total_aud_bytes.to_le_bytes())?;
            f.write_all(&0xFFFFFFFFu32.to_le_bytes())?;
            f.write_all(&(block_align as u32).to_le_bytes())?;
            f.write_all(&[0u8; 8])?;

            f.write_all(b"strf")?;
            f.write_all(&16u32.to_le_bytes())?;
            f.write_all(&1u16.to_le_bytes())?;
            f.write_all(&channels.to_le_bytes())?;
            f.write_all(&sample_rate.to_le_bytes())?;
            f.write_all(&avg_bytes_per_sec.to_le_bytes())?;
            f.write_all(&block_align.to_le_bytes())?;
            f.write_all(&16u16.to_le_bytes())?;
        }
    }

    f.write_all(b"LIST")?;
    f.write_all(&movi_payload_bytes.to_le_bytes())?;
    f.write_all(b"movi")?;

    let mut index_entries: Vec<([u8; 4], u32, u32)> = Vec::with_capacity(total_index_entries);
    let mut current_chunk_offset = 4u32;
    let mut cursor = 0usize;

    // كتابة متداخلة إطاراً بإطار: 00dc (فيديو) يليه مباشرة 01wb (صوت الإطار المقابل)
    for (frame_idx, &sz) in sizes.iter().enumerate() {
        index_entries.push((*b"00dc", current_chunk_offset, sz));
        f.write_all(b"00dc")?;
        f.write_all(&sz.to_le_bytes())?;
        let end = cursor + (sz as usize);
        f.write_all(&all_frames[cursor..end])?;
        if sz % 2 == 1 {
            f.write_all(&[0u8])?;
        }
        cursor = end;
        current_chunk_offset = current_chunk_offset
            .saturating_add(8)
            .saturating_add(sz)
            .saturating_add(sz % 2);

        if let Some(aud_slice) = audio_slices.get(frame_idx) {
            let aud_sz = aud_slice.len() as u32;
            index_entries.push((*b"01wb", current_chunk_offset, aud_sz));
            f.write_all(b"01wb")?;
            f.write_all(&aud_sz.to_le_bytes())?;
            f.write_all(aud_slice)?;
            if aud_sz % 2 == 1 {
                f.write_all(&[0u8])?;
            }
            current_chunk_offset = current_chunk_offset
                .saturating_add(8)
                .saturating_add(aud_sz)
                .saturating_add(aud_sz % 2);
        }
    }

    f.write_all(b"idx1")?;
    f.write_all(&idx1_bytes.to_le_bytes())?;
    for (tag, offset, sz) in index_entries {
        f.write_all(&tag)?;
        f.write_all(&0x10u32.to_le_bytes())?;
        f.write_all(&offset.to_le_bytes())?;
        f.write_all(&sz.to_le_bytes())?;
    }

    f.flush()?;
    Ok(())
}
