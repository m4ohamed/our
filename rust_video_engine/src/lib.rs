// rust_video_engine/src/lib.rs
// محرك Rust احترافي مستلهم من معمارية FilmCraft (storytold/filmcraft) و EffectCraft (storytold/effectcraft)
// يضم:
// 1. filmcraft-time: نظام التوقيت الصحيح الخالي من الانجراف (Exact Integer Ticks: 254,016,000,000 ticks/sec)
// 2. filmcraft-project::keyframe: حلال Newton-Raphson + Bisection لمنحنيات Cubic Bezier الزمنية و Catmull-Rom
// 3. filmcraft-color: مصفوفات Lumetri Rec.709 وتحويل الفضاء اللوني ITU-R BT.709 Studio-Swing مع 2x2 Chroma Box-Filter
// 4. filmcraft-render-parallel: معالجة دفعات الإطارات بالتوازي عبر كافة أنوية المعالج (std::thread::scope Multi-Core Batching)
// 5. filmcraft-audio-dsp: مازج صوت متعدد المسارات بدقة الـ Tick، وإعادة أخذ العينات (Resampling)، وتلاشي Constant-Power Sine مبني على الإطارات الزمنية، ومحدد ذروة مع تقدير القمم بين العينات 4x
// 6. filmcraft-avi: تجميع وفحص حاوية RIFF/AVI بتداخل إطار بإطار (Frame-Interleaved 00dc + 01wb WAVEFORMATEX PCM) مع عقود ذاكرة آمنة عبر FFI

use std::f64::consts::PI;
use std::fs::File;
use std::io::{BufWriter, Read, Seek, SeekFrom, Write};
use std::slice;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;

/// عدد النبضات الزمنية في الثانية الواحدة كما في `filmcraft-time`
/// يقبل القسمة بدون باقٍ على كافة معدلات الإطارات (23.976, 24, 25, 29.97, 30, 50, 59.94, 60, 120)
/// وكافة ترددات الصوت القياسية (8000, 11025, 16000, 22050, 32000, 44100, 48000, 96000, 192000 Hz)
pub const TICKS_PER_SECOND: i64 = 254_016_000_000;

/// الحد الأقصى المسموح به لأبعاد الإطار لمنع تجاوز سعة الأعداد الصحيحة أو استنزاف الذاكرة (VID-004 / VID-011)
pub const MAX_FRAME_DIMENSION: u32 = 8192;

/// الحد الأقصى لعدد الإطارات في عملية تجميع واحدة عبر الذاكرة (VID-004)
pub const MAX_MUX_FRAMES: usize = 108_000; // حتى 30 دقيقة عند 60 FPS

/// الحد الأقصى لحجم البيانات المجمعة في استدعاء FFI واحد (1.5 GB) لمنع القراءة خارج الحدود أو فشل التخصيص غير المتحكم فيه
pub const MAX_FFI_BUFFER_BYTES: usize = 1_536 * 1024 * 1024;

/// التوقيع القياسي لملفات PNG (8 بايت) للتحقق من سلامة إطارات `00dc`
pub const PNG_SIGNATURE: [u8; 8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

#[repr(C)]
#[derive(Copy, Clone, Debug, PartialEq)]
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
/// القاعدة العددية (VID-010): تقريب إلى أقرب عدد صحيح (`round()`) مع حماية من القيم غير المحدودة
#[no_mangle]
pub extern "C" fn rust_seconds_to_ticks(seconds: f64) -> i64 {
    if !seconds.is_finite() {
        return 0;
    }
    (seconds * (TICKS_PER_SECOND as f64)).round() as i64
}

/// تحويل النبضات الصحيحة إلى ثوانٍ
#[no_mangle]
pub extern "C" fn rust_ticks_to_seconds(ticks: i64) -> f64 {
    (ticks as f64) / (TICKS_PER_SECOND as f64)
}

/// تحويل النبضات الزمنية (Ticks) إلى فهرس إطار عينة صوتية دقيق (Exact Sample Frame Index)
/// القاعدة العددية الموحدة بين Rust وDart (VID-010): اقتطاع القسمة الصحيحة (`floor` للقيم الموجبة) عبر حساب 128-بت
#[no_mangle]
pub extern "C" fn rust_ticks_to_audio_sample(ticks: i64, sample_rate: u32) -> i64 {
    if ticks <= 0 || sample_rate == 0 {
        return 0;
    }
    ((ticks as i128 * sample_rate as i128) / (TICKS_PER_SECOND as i128)) as i64
}

/// حساب وقت الإطار بالثواني من رقم الإطار ومعدل الإطارات المستهدف عبر النبضات الزمنية الدقيقة (VID-002 / VID-010)
#[no_mangle]
pub extern "C" fn rust_frame_index_to_seconds(frame_index: u32, target_fps: u32) -> f64 {
    if target_fps == 0 {
        return 0.0;
    }
    let ticks_per_frame = TICKS_PER_SECOND / (target_fps as i64);
    let frame_ticks = (frame_index as i64).saturating_mul(ticks_per_frame);
    rust_ticks_to_seconds(frame_ticks)
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
/// كما في `filmcraft-project::keyframe` للحصول على قيمة y(u) الدقيقة زمنياً (VID-010)
#[no_mangle]
pub extern "C" fn rust_solve_cubic_bezier_2d(
    x1: f64,
    y1: f64,
    x2: f64,
    y2: f64,
    t: f64,
) -> f64 {
    if !t.is_finite() {
        return 0.0;
    }
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
            if clamped < 1.0 {
                0.0
            } else {
                1.0
            }
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
pub fn compute_lumetri_matrix_array(
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
    if frame_a.is_null()
        || frame_b.is_null()
        || output.is_null()
        || length == 0
        || length > MAX_FFI_BUFFER_BYTES
    {
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

/// تحويل إطار RGBA8888 مفرد إلى NV12 بمعيار ITU-R BT.709 Studio-Swing مع فلتر 2x2 Box-Filter للكروما
/// يفترض التحقق المسبق من أن الأبعاد زوجية (`w % 2 == 0 && h % 2 == 0`) وأن أحجام الشرائح مطابقة.
#[inline]
pub fn convert_single_rgba_to_bt709_nv12(rgba: &[u8], nv12: &mut [u8], w: usize, h: usize) {
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
            y_plane[dst_row + x] =
                (((47 * r + 157 * g + 16 * b + 128) >> 8) + 16).clamp(16, 235) as u8;
        }
    }

    let half_h = h / 2;
    let half_w = w / 2;
    for uy in 0..half_h {
        let y0 = uy * 2;
        let y1 = y0 + 1;
        let row0 = y0 * w * 4;
        let row1 = y1 * w * 4;
        let uv_dst_row = uy * w;

        for ux in 0..half_w {
            let x0 = ux * 2;
            let x1 = x0 + 1;

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
            uv_plane[dst_idx] = u_val;
            uv_plane[dst_idx + 1] = v_val;
        }
    }
}

/// تحويل إطار RGBA8888 إلى فضاء ITU-R BT.709 Studio-Swing YUV420 مع فلتر 2x2 للكروما ودعم Strides مخصصة (VID-004 / VID-011)
/// رموز الإرجاع:
///  0 = نجاح
/// -1 = مؤشر فارغ أو أبعاد صفرية
/// -2 = تجاوز الحد الأقصى للأبعاد أو عدم توافق Strides
/// -3 = أبعاد فردية غير مدعومة في YUV420 (يتطلب عرضاً وارتفاعاً زوجيين)
/// -4 = تداخل غير آمن بين مؤشري U و V (يجب استخدام `rust_rgba_to_nv12` لـ NV12 المتداخل)
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
    if width > MAX_FRAME_DIMENSION || height > MAX_FRAME_DIMENSION {
        return -2;
    }
    if width % 2 != 0 || height % 2 != 0 {
        return -3;
    }
    if u_out_ptr == v_out_ptr {
        return -4;
    }

    let w = width as usize;
    let h = height as usize;
    let half_w = w / 2;
    let half_h = h / 2;

    let y_stride = (y_row_stride as usize).max(w);
    let uv_px_stride = (uv_pixel_stride as usize).max(1);
    let min_uv_row_bytes = match half_w.checked_mul(uv_px_stride) {
        Some(v) => v,
        None => return -2,
    };
    let uv_stride = (uv_row_stride as usize).max(min_uv_row_bytes);

    let rgba_len = match w.checked_mul(h).and_then(|px| px.checked_mul(4)) {
        Some(v) if v <= MAX_FFI_BUFFER_BYTES => v,
        _ => return -2,
    };
    let y_plane_len = match (h - 1).checked_mul(y_stride).and_then(|r| r.checked_add(w)) {
        Some(v) => v,
        None => return -2,
    };
    let uv_plane_len = match (half_h - 1)
        .checked_mul(uv_stride)
        .and_then(|r| r.checked_add((half_w - 1) * uv_px_stride + 1))
    {
        Some(v) => v,
        None => return -2,
    };

    let rgba = slice::from_raw_parts(rgba_ptr, rgba_len);
    let y_plane = slice::from_raw_parts_mut(y_out_ptr, y_plane_len);

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

    // 2. حساب الكروما (Cb/Cr) عبر متوسط مربع 2x2 بكسل (2x2 Box-Filter)
    // نستخدم الكتابة عبر المؤشرات المحددة بالحدود (`u_out_ptr.add(...)` و `v_out_ptr.add(...)`)
    // لمنع أي تعارض Aliasing في Rust عندما تكون مستويات U و V متداخلة (Semi-Planar NV12/NV21).
    for uy in 0..half_h {
        let y0 = uy * 2;
        let y1 = y0 + 1;
        let row0 = y0 * w * 4;
        let row1 = y1 * w * 4;
        let uv_dst_row = uy * uv_stride;

        for ux in 0..half_w {
            let x0 = ux * 2;
            let x1 = x0 + 1;

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
            if dst_idx < uv_plane_len {
                *u_out_ptr.add(dst_idx) = u_val;
                *v_out_ptr.add(dst_idx) = v_val;
            }
        }
    }

    0
}

/// تحويل إطار RGBA8888 إلى فضاء YUV420 Semi-Planar (NV12) بمعيار ITU-R BT.709 وفلتر 2x2 للكروما (VID-004 / VID-011)
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
    if width > MAX_FRAME_DIMENSION || height > MAX_FRAME_DIMENSION {
        return -2;
    }
    if width % 2 != 0 || height % 2 != 0 {
        return -3;
    }

    let w = width as usize;
    let h = height as usize;
    let rgba_size = match w.checked_mul(h).and_then(|px| px.checked_mul(4)) {
        Some(v) if v <= MAX_FFI_BUFFER_BYTES => v,
        _ => return -2,
    };
    let nv12_size = (w * h * 3) / 2;

    let rgba_slice = slice::from_raw_parts(rgba_ptr, rgba_size);
    let nv12_slice = slice::from_raw_parts_mut(nv12_out_ptr, nv12_size);
    convert_single_rgba_to_bt709_nv12(rgba_slice, nv12_slice, w, h);
    0
}

/// تطبيق Lumetri + Vignette على إطار RGBA8888 واحد في المكان (In-Place)
#[inline]
pub fn apply_lumetri_and_vignette_to_frame(
    frame: &mut [u8],
    w: usize,
    h: usize,
    m: &[f64; 20],
    vig: f64,
) {
    let cx = (w as f64) * 0.5;
    let cy = (h as f64) * 0.5;
    let inv_max_dist = 1.0 / (cx * cx + cy * cy).sqrt().max(1.0);

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
                    let factor = 1.0 - vig * ((dist - 0.45) / 0.55).clamp(0.0, 1.0);
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

/// معالجة دفعة كاملة من إطارات RGBA8888 بالتوازي عبر جميع أنوية المعالج (Multi-Core Scoped Threads)
/// لتطبيق مصفوفة ألوان Lumetri والتظليل السينمائي (Vignette) في وقت واحد على عدة إطارات (VID-004 / VID-007 / VID-016)
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
    if width > MAX_FRAME_DIMENSION || height > MAX_FRAME_DIMENSION || num_frames > MAX_MUX_FRAMES {
        return -2;
    }
    if !exposure.is_finite()
        || !contrast.is_finite()
        || !saturation.is_finite()
        || !temperature.is_finite()
        || !faded_film.is_finite()
        || !vignette.is_finite()
    {
        return -3;
    }

    let w = width as usize;
    let h = height as usize;
    let frame_bytes = match w.checked_mul(h).and_then(|px| px.checked_mul(4)) {
        Some(v) if v > 0 => v,
        _ => return -2,
    };
    let total_bytes = match frame_bytes.checked_mul(num_frames) {
        Some(v) if v > 0 && v <= MAX_FFI_BUFFER_BYTES => v,
        _ => return -2,
    };

    let m = compute_lumetri_matrix_array(exposure, contrast, saturation, temperature, faded_film);
    let vig = vignette.clamp(0.0, 0.85);
    let batch_slice = slice::from_raw_parts_mut(rgba_batch_ptr, total_bytes);

    let max_threads = thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4)
        .clamp(1, 8)
        .min(num_frames);

    if max_threads <= 1 {
        for frame in batch_slice.chunks_exact_mut(frame_bytes) {
            apply_lumetri_and_vignette_to_frame(frame, w, h, &m, vig);
        }
        return 0;
    }

    let frames_per_chunk = (num_frames + max_threads - 1) / max_threads;
    let bytes_per_chunk = frames_per_chunk * frame_bytes;

    thread::scope(|s| {
        for chunk in batch_slice.chunks_mut(bytes_per_chunk) {
            s.spawn(move || {
                for frame in chunk.chunks_exact_mut(frame_bytes) {
                    apply_lumetri_and_vignette_to_frame(frame, w, h, &m, vig);
                }
            });
        }
    });

    0
}

/// تحويل دفعة إطارات RGBA8888 بالتوازي عبر جميع أنوية المعالج (Multi-Core Scoped Threads)
/// إلى فضاء ITU-R BT.709 Studio-Swing NV12 مع فلتر 2x2 Box-Filter للكروما (VID-004 / VID-011 / VID-016)
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
    if width > MAX_FRAME_DIMENSION || height > MAX_FRAME_DIMENSION || num_frames > MAX_MUX_FRAMES {
        return -2;
    }
    if width % 2 != 0 || height % 2 != 0 {
        return -3;
    }

    let w = width as usize;
    let h = height as usize;
    let rgba_frame_size = match w.checked_mul(h).and_then(|px| px.checked_mul(4)) {
        Some(v) if v > 0 => v,
        _ => return -2,
    };
    let nv12_frame_size = (w * h * 3) / 2;

    let total_rgba = match rgba_frame_size.checked_mul(num_frames) {
        Some(v) if v > 0 && v <= MAX_FFI_BUFFER_BYTES => v,
        _ => return -2,
    };
    let total_nv12 = match nv12_frame_size.checked_mul(num_frames) {
        Some(v) if v > 0 && v <= MAX_FFI_BUFFER_BYTES => v,
        _ => return -2,
    };

    let rgba_all = slice::from_raw_parts(rgba_batch_ptr, total_rgba);
    let nv12_all = slice::from_raw_parts_mut(nv12_batch_out_ptr, total_nv12);

    let max_threads = thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4)
        .clamp(1, 8)
        .min(num_frames);

    if max_threads <= 1 {
        for (src_frame, dst_frame) in rgba_all
            .chunks_exact(rgba_frame_size)
            .zip(nv12_all.chunks_exact_mut(nv12_frame_size))
        {
            convert_single_rgba_to_bt709_nv12(src_frame, dst_frame, w, h);
        }
        return 0;
    }

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

/// محدد ذروة للعينة المفردة بمنحنى ناعم (Soft-Knee Tanh Sample-Peak Limiter) (VID-013)
/// يحافظ على خطية الإشارة تماماً تحت عتبة `KNEE_START` (28,000) ويضغط القمم تدريجياً نحو `MAX_CEILING` (32,700).
#[inline]
pub fn soft_knee_sample_peak_limit(sample: f64) -> i16 {
    const KNEE_START: f64 = 28_000.0;
    const MAX_CEILING: f64 = 32_700.0;
    const HEADROOM: f64 = MAX_CEILING - KNEE_START;

    if !sample.is_finite() {
        return 0;
    }
    let abs_s = sample.abs();
    if abs_s <= KNEE_START {
        return sample.round() as i16;
    }
    let sign = sample.signum();
    let excess = (abs_s - KNEE_START) / HEADROOM;
    let compressed = KNEE_START + HEADROOM * excess.tanh();
    (sign * compressed).round().clamp(-32767.0, 32767.0) as i16
}

/// تقدير القمة الحقيقية بين العينات (4x Oversampled Cubic Hermite / Catmull-Rom Inter-Sample Peak) (VID-013)
/// يفحص النقاط الفرعية t = 0.25, 0.50, 0.75 بين s1 و s2 لاكتشاف أي تجاوز بين العينات (Inter-Sample Overshoot).
#[inline]
pub fn estimate_intersample_peak_4x(s0: f64, s1: f64, s2: f64, s3: f64) -> f64 {
    let mut max_abs = s1.abs().max(s2.abs());
    for &t in &[0.25_f64, 0.50_f64, 0.75_f64] {
        let interp = rust_catmull_rom_spline(s0, s1, s2, s3, t).abs();
        if interp > max_abs {
            max_abs = interp;
        }
    }
    max_abs
}

/// محدد القمة الحقيقية بين العينات (True-Peak Aware Soft-Knee Limiter) (VID-013)
/// يجمع بين فحص القمة بين العينات (4x Inter-Sample Peak) ومنحنى الضغط الناعم Soft-Knee Tanh.
#[inline]
pub fn soft_knee_true_peak_limit_4x(s0: f64, s1: f64, s2: f64, s3: f64) -> i16 {
    const KNEE_START: f64 = 28_000.0;
    let true_peak = estimate_intersample_peak_4x(s0, s1, s2, s3);
    let sample_abs = s1.abs();
    if true_peak > KNEE_START && true_peak > sample_abs && sample_abs > 1.0 {
        // إذا كانت القمة بين العينات أعلى من قيمة العينة الرقمية وتجاوزت ركبة المحدد،
        // نطبق نسبة خفض وقائية متناسبة مع القمة الحقيقية
        let limited_peak = (soft_knee_sample_peak_limit(true_peak) as f64).abs();
        let attenuation = (limited_peak / true_peak).clamp(0.5, 1.0);
        return soft_knee_sample_peak_limit(s1 * attenuation);
    }
    soft_knee_sample_peak_limit(s1)
}

/// توافق خلفي مع الاسم السابق مع توثيق أنه يطبق منحنى Soft-Knee على العينة
#[inline]
pub fn soft_knee_true_peak_limit(sample: f64) -> i16 {
    soft_knee_sample_peak_limit(sample)
}

/// إعادة أخذ العينات (Linear Resampling) وتحويل عدد القنوات (Mono <-> Stereo) لمؤثر صوتي PCM16 LE (VID-005)
pub fn resample_and_convert_pcm16(
    src_pcm_bytes: &[u8],
    src_sample_rate: u32,
    src_channels: u16,
    dst_sample_rate: u32,
    dst_channels: u16,
) -> Vec<i16> {
    if src_sample_rate == 0 || src_channels == 0 || dst_sample_rate == 0 || dst_channels == 0 {
        return Vec::new();
    }
    let src_ch = src_channels as usize;
    let dst_ch = dst_channels as usize;
    let frame_stride = src_ch * 2;
    let src_frames = src_pcm_bytes.len() / frame_stride;
    if src_frames == 0 {
        return Vec::new();
    }

    // قراءة إطارات المصدر وتحويلها إلى عدد قنوات الهدف أولاً
    let mut normalized_frames: Vec<f64> = Vec::with_capacity(src_frames * dst_ch);
    for f_idx in 0..src_frames {
        let base = f_idx * frame_stride;
        if src_ch == dst_ch {
            for c in 0..dst_ch {
                let off = base + c * 2;
                let s = i16::from_le_bytes([src_pcm_bytes[off], src_pcm_bytes[off + 1]]) as f64;
                normalized_frames.push(s);
            }
        } else if src_ch == 1 && dst_ch == 2 {
            let s = i16::from_le_bytes([src_pcm_bytes[base], src_pcm_bytes[base + 1]]) as f64;
            normalized_frames.push(s);
            normalized_frames.push(s);
        } else if src_ch >= 2 && dst_ch == 1 {
            let mut sum = 0.0_f64;
            for c in 0..src_ch {
                let off = base + c * 2;
                sum += i16::from_le_bytes([src_pcm_bytes[off], src_pcm_bytes[off + 1]]) as f64;
            }
            normalized_frames.push(sum / (src_ch as f64));
        } else {
            for c in 0..dst_ch {
                let src_c = c % src_ch;
                let off = base + src_c * 2;
                let s = i16::from_le_bytes([src_pcm_bytes[off], src_pcm_bytes[off + 1]]) as f64;
                normalized_frames.push(s);
            }
        }
    }

    if src_sample_rate == dst_sample_rate {
        return normalized_frames
            .into_iter()
            .map(|v| v.round().clamp(-32768.0, 32767.0) as i16)
            .collect();
    }

    let dst_frames =
        (((src_frames as u128) * (dst_sample_rate as u128) + (src_sample_rate as u128 / 2))
            / (src_sample_rate as u128)) as usize;
    if dst_frames == 0 {
        return Vec::new();
    }

    let mut resampled: Vec<i16> = Vec::with_capacity(dst_frames * dst_ch);
    let rate_ratio = (src_sample_rate as f64) / (dst_sample_rate as f64);

    for out_f in 0..dst_frames {
        let src_pos = (out_f as f64) * rate_ratio;
        let idx0 = (src_pos.floor() as usize).min(src_frames - 1);
        let idx1 = (idx0 + 1).min(src_frames - 1);
        let frac = (src_pos - (idx0 as f64)).clamp(0.0, 1.0);

        for c in 0..dst_ch {
            let v0 = normalized_frames[idx0 * dst_ch + c];
            let v1 = normalized_frames[idx1 * dst_ch + c];
            let interp = v0 + (v1 - v0) * frac;
            resampled.push(interp.round().clamp(-32768.0, 32767.0) as i16);
        }
    }

    resampled
}

/// دمج مؤثر صوتي (Overlay Track PCM 16-bit LE) مع دعم اختلاف معدل العينات وعدد القنوات (VID-005)
#[no_mangle]
pub unsafe extern "C" fn rust_mix_pcm16_overlay_resampled(
    master_pcm_ptr: *mut u8,
    master_byte_len: usize,
    overlay_pcm_ptr: *const u8,
    overlay_byte_len: usize,
    master_sample_rate: u32,
    master_channels: u16,
    overlay_sample_rate: u32,
    overlay_channels: u16,
    start_time_seconds: f64,
    overlay_volume: f64,
) -> i32 {
    if master_pcm_ptr.is_null()
        || overlay_pcm_ptr.is_null()
        || master_byte_len < 2
        || overlay_byte_len < 2
        || master_sample_rate == 0
        || master_channels == 0
        || overlay_sample_rate == 0
        || overlay_channels == 0
        || master_byte_len > MAX_FFI_BUFFER_BYTES
        || overlay_byte_len > MAX_FFI_BUFFER_BYTES
    {
        return -1;
    }

    let master_frame_stride = (master_channels as usize) * 2;
    let aligned_master_len = (master_byte_len / master_frame_stride) * master_frame_stride;
    if aligned_master_len == 0 {
        return -1;
    }

    let master = slice::from_raw_parts_mut(master_pcm_ptr, aligned_master_len);
    let overlay_raw = slice::from_raw_parts(overlay_pcm_ptr, overlay_byte_len);

    let start_ticks = rust_seconds_to_ticks(start_time_seconds.max(0.0));
    let start_frame = rust_ticks_to_audio_sample(start_ticks, master_sample_rate) as usize;
    let start_byte = start_frame.saturating_mul(master_frame_stride);

    if start_byte >= aligned_master_len {
        return 0;
    }

    let gain = if overlay_volume.is_finite() {
        overlay_volume.clamp(0.0, 2.0)
    } else {
        0.0
    };

    // إذا تطابق معدل العينات وعدد القنوات، نمزج مباشرة دون تخصيص إضافي
    if master_sample_rate == overlay_sample_rate && master_channels == overlay_channels {
        let aligned_overlay_len = (overlay_byte_len / master_frame_stride) * master_frame_stride;
        let available_bytes = (aligned_master_len - start_byte).min(aligned_overlay_len);
        let num_samples = available_bytes / 2;

        for i in 0..num_samples {
            let m_idx = start_byte + i * 2;
            let o_idx = i * 2;
            let m_sample = i16::from_le_bytes([master[m_idx], master[m_idx + 1]]) as f64;
            let o_sample =
                i16::from_le_bytes([overlay_raw[o_idx], overlay_raw[o_idx + 1]]) as f64;

            let mixed = m_sample + o_sample * gain;
            let limited = soft_knee_sample_peak_limit(mixed);
            let bytes = limited.to_le_bytes();
            master[m_idx] = bytes[0];
            master[m_idx + 1] = bytes[1];
        }
        return 0;
    }

    // إعادة أخذ العينات وتوحيد القنوات قبل المزج
    let converted_samples = resample_and_convert_pcm16(
        overlay_raw,
        overlay_sample_rate,
        overlay_channels,
        master_sample_rate,
        master_channels,
    );
    let max_master_samples = (aligned_master_len - start_byte) / 2;
    let mix_samples = converted_samples.len().min(max_master_samples);

    for i in 0..mix_samples {
        let m_idx = start_byte + i * 2;
        let m_sample = i16::from_le_bytes([master[m_idx], master[m_idx + 1]]) as f64;
        let o_sample = converted_samples[i] as f64;

        let mixed = m_sample + o_sample * gain;
        let limited = soft_knee_sample_peak_limit(mixed);
        let bytes = limited.to_le_bytes();
        master[m_idx] = bytes[0];
        master[m_idx + 1] = bytes[1];
    }

    0
}

/// دمج مؤثر صوتي (Overlay Track PCM 16-bit LE) فوق المسار الصوتي الرئيسي عند زمن بداية محدد بالثواني
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
    rust_mix_pcm16_overlay_resampled(
        master_pcm_ptr,
        master_byte_len,
        overlay_pcm_ptr,
        overlay_byte_len,
        sample_rate,
        channels,
        sample_rate,
        channels,
        start_time_seconds,
        overlay_volume,
    )
}

/// معالجة عينات الصوت PCM 16-bit LE بأسلوب `filmcraft-audio-dsp` (VID-001 / VID-013)
/// - يحسب الزمن بدقة الإطار الصوتي (`frame_idx / sample_rate`) بحيث تحصل جميع قنوات الإطار الواحد (مثل L و R في Stereo)
///   على معامل التلاشي نفسه تماماً في اللحظة الزمنية نفسها.
/// - يضبط نافذة التلاشي تلقائياً في المقاطع القصيرة لمنع تداخل Fade-In و Fade-Out أو الانقطاع المفاجئ.
/// - يطبق محدد القمة الناعم مع تقدير القمم بين العينات 4x (`soft_knee_true_peak_limit_4x`).
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
    if pcm_bytes_ptr.is_null()
        || pcm_byte_len < 2
        || sample_rate == 0
        || channels == 0
        || pcm_byte_len > MAX_FFI_BUFFER_BYTES
    {
        return -1;
    }

    let ch = channels as usize;
    let frame_byte_stride = match ch.checked_mul(2) {
        Some(v) if v > 0 => v,
        _ => return -2,
    };
    let total_frames = pcm_byte_len / frame_byte_stride;
    if total_frames == 0 {
        return -2;
    }

    let valid_byte_len = total_frames * frame_byte_stride;
    let pcm = slice::from_raw_parts_mut(pcm_bytes_ptr, valid_byte_len);

    let total_seconds = (total_frames as f64) / (sample_rate as f64);
    let default_fade_sec = 1.2_f64;
    let fade_window = if fade_in != 0 && fade_out != 0 {
        default_fade_sec.min(total_seconds * 0.5)
    } else if fade_in != 0 || fade_out != 0 {
        default_fade_sec.min(total_seconds)
    } else {
        0.0
    };

    let base_gain = if volume.is_finite() {
        volume.clamp(0.0, 1.5)
    } else {
        1.0
    };

    for frame_idx in 0..total_frames {
        let current_sec = (frame_idx as f64) / (sample_rate as f64);
        // حساب الزمن المتبقي من نهاية الإطار الأخير بحيث يصل التلاشي عند الإطار الأخير إلى الصفر بسلاسة
        let remaining_frames = (total_frames - 1).saturating_sub(frame_idx);
        let remaining_sec = (remaining_frames as f64) / (sample_rate as f64);

        let mut gain = base_gain;

        if fade_in != 0 && fade_window > 1e-9 && current_sec < fade_window {
            let ratio = (current_sec / fade_window).clamp(0.0, 1.0);
            gain *= (ratio * PI * 0.5).sin();
        }
        if fade_out != 0 && fade_window > 1e-9 && remaining_sec < fade_window {
            let ratio = (remaining_sec / fade_window).clamp(0.0, 1.0);
            gain *= (ratio * PI * 0.5).sin();
        }

        let frame_base = frame_idx * frame_byte_stride;
        for c in 0..ch {
            let byte_idx = frame_base + c * 2;
            let raw_s1 = i16::from_le_bytes([pcm[byte_idx], pcm[byte_idx + 1]]) as f64 * gain;

            // قراءة العينة التالية لتقدير القمة بين العينات (4x Inter-Sample Peak) عند الاقتراب من سقف الركبة
            let limited = if raw_s1.abs() > 24_000.0 && frame_idx + 1 < total_frames {
                let next_idx = (frame_idx + 1) * frame_byte_stride + c * 2;
                let raw_s2 =
                    i16::from_le_bytes([pcm[next_idx], pcm[next_idx + 1]]) as f64 * gain;
                let prev_s0 = if frame_idx > 0 {
                    let prev_idx = (frame_idx - 1) * frame_byte_stride + c * 2;
                    i16::from_le_bytes([pcm[prev_idx], pcm[prev_idx + 1]]) as f64
                } else {
                    raw_s1
                };
                let next_s3 = if frame_idx + 2 < total_frames {
                    let next2_idx = (frame_idx + 2) * frame_byte_stride + c * 2;
                    i16::from_le_bytes([pcm[next2_idx], pcm[next2_idx + 1]]) as f64 * gain
                } else {
                    raw_s2
                };
                soft_knee_true_peak_limit_4x(prev_s0, raw_s1, raw_s2, next_s3)
            } else {
                soft_knee_sample_peak_limit(raw_s1)
            };

            let out_bytes = limited.to_le_bytes();
            pcm[byte_idx] = out_bytes[0];
            pcm[byte_idx + 1] = out_bytes[1];
        }
    }
    0
}

/// التحقق من صحة جدول أحجام الإطارات ومجموعها مقابل السعة الفعلية للمخزن (VID-004)
fn validate_frames_buffer_contract(
    sizes: &[u32],
    actual_concat_capacity: Option<usize>,
    width: u32,
    height: u32,
    fps: u32,
) -> Result<usize, i32> {
    if sizes.is_empty() || sizes.len() > MAX_MUX_FRAMES {
        return Err(-4);
    }
    if width == 0
        || height == 0
        || width > MAX_FRAME_DIMENSION
        || height > MAX_FRAME_DIMENSION
        || fps == 0
        || fps > 240
    {
        return Err(-5);
    }

    let mut total_bytes: usize = 0;
    for &sz in sizes {
        if sz == 0 || (sz as usize) > 64 * 1024 * 1024 {
            return Err(-6);
        }
        total_bytes = match total_bytes.checked_add(sz as usize) {
            Some(v) if v <= MAX_FFI_BUFFER_BYTES => v,
            _ => return Err(-7),
        };
    }

    if let Some(cap) = actual_concat_capacity {
        if total_bytes > cap {
            return Err(-8);
        }
    }

    Ok(total_bytes)
}

/// تجميع سلسلة إطارات مضغوطة (PNG / MJPG) داخل ملف فيديو قياسي RIFF AVI مع التحقق الصريح من طول المخزن (VID-004)
#[no_mangle]
pub unsafe extern "C" fn rust_mux_frames_and_pcm_to_avi_checked(
    output_path_ptr: *const u8,
    output_path_len: usize,
    frames_concat_ptr: *const u8,
    frames_concat_len: usize,
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
    if output_path_ptr.is_null()
        || output_path_len == 0
        || output_path_len > 4096
        || frames_concat_ptr.is_null()
        || frame_sizes_ptr.is_null()
        || num_frames == 0
    {
        return -1;
    }

    let path_bytes = slice::from_raw_parts(output_path_ptr, output_path_len);
    let path_str = match std::str::from_utf8(path_bytes) {
        Ok(s) if !s.trim().is_empty() => s,
        _ => return -2,
    };

    if num_frames > MAX_MUX_FRAMES {
        return -4;
    }
    let sizes = slice::from_raw_parts(frame_sizes_ptr, num_frames);
    let total_bytes =
        match validate_frames_buffer_contract(sizes, Some(frames_concat_len), width, height, fps) {
            Ok(tot) => tot,
            Err(code) => return code,
        };

    let all_frames = slice::from_raw_parts(frames_concat_ptr, total_bytes);

    let audio_opt = if !pcm_data_ptr.is_null()
        && pcm_byte_len > 0
        && sample_rate > 0
        && channels > 0
    {
        if pcm_byte_len > MAX_FFI_BUFFER_BYTES {
            return -9;
        }
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
/// داخل حاوية RIFF AVI قياسية كما في `filmcraft-avi` (مع تحقق صارم من الحدود والأبعاد والأحجام VID-004)
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
    if output_path_ptr.is_null()
        || output_path_len == 0
        || output_path_len > 4096
        || frames_concat_ptr.is_null()
        || frame_sizes_ptr.is_null()
        || num_frames == 0
        || num_frames > MAX_MUX_FRAMES
    {
        return -1;
    }
    let sizes = slice::from_raw_parts(frame_sizes_ptr, num_frames);
    let total_bytes = match validate_frames_buffer_contract(sizes, None, width, height, fps) {
        Ok(tot) => tot,
        Err(code) => return code,
    };

    rust_mux_frames_and_pcm_to_avi_checked(
        output_path_ptr,
        output_path_len,
        frames_concat_ptr,
        total_bytes,
        frame_sizes_ptr,
        num_frames,
        width,
        height,
        fps,
        pcm_data_ptr,
        pcm_byte_len,
        sample_rate,
        channels,
    )
}

pub fn write_avi_container(
    path: &str,
    all_frames: &[u8],
    sizes: &[u32],
    width: u32,
    height: u32,
    fps: u32,
    audio_pcm: Option<(&[u8], u32, u16)>,
) -> std::io::Result<()> {
    if sizes.is_empty() || width == 0 || height == 0 || fps == 0 {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "Invalid AVI parameters: empty frames or zero dimensions/fps",
        ));
    }

    let expected_total: usize = sizes.iter().map(|&s| s as usize).sum();
    if all_frames.len() < expected_total {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "Frame buffer smaller than sum of frame sizes",
        ));
    }

    let file = File::create(path)?;
    let mut f = BufWriter::with_capacity(256 * 1024, file);
    let num_frames = sizes.len() as u32;
    let safe_fps = fps.max(1);
    let usec_per_frame = (1_000_000u64 + (safe_fps as u64 / 2)) / (safe_fps as u64);
    let usec_per_frame_u32 = usec_per_frame as u32;
    let frame_buffer_size = width.saturating_mul(height).saturating_mul(4);
    let max_bytes_per_sec = frame_buffer_size.saturating_mul(safe_fps);

    // تقسيم الصوت إلى شرائح متداخلة مع كل إطار فيديو (1:1 Frame-Interleaved 00dc + 01wb)
    // باستخدام حساب التوقيت الدقيق لكل إطار لمنع الانحراف التراكمي
    let mut audio_slices: Vec<&[u8]> = Vec::new();
    if let Some((pcm_bytes, sample_rate, channels)) = audio_pcm {
        let block_align = (channels.max(1) as usize) * 2;
        let aligned_total = (pcm_bytes.len() / block_align) * block_align;
        let valid_pcm = &pcm_bytes[..aligned_total];
        let total_audio_frames = aligned_total / block_align;

        if !valid_pcm.is_empty() && !sizes.is_empty() {
            let mut aud_frame_cursor = 0usize;
            for i in 0..sizes.len() {
                if aud_frame_cursor >= total_audio_frames {
                    break;
                }
                let next_target_frame = if i + 1 == sizes.len() {
                    total_audio_frames
                } else {
                    let target = (((i + 1) as u128 * (sample_rate as u128))
                        / (safe_fps as u128)) as usize;
                    target.min(total_audio_frames)
                };
                if next_target_frame > aud_frame_cursor {
                    let byte_start = aud_frame_cursor * block_align;
                    let byte_end = next_target_frame * block_align;
                    audio_slices.push(&valid_pcm[byte_start..byte_end]);
                    aud_frame_cursor = next_target_frame;
                } else {
                    audio_slices.push(&[]);
                }
            }
        }
    }

    let non_empty_audio_chunks = audio_slices.iter().filter(|s| !s.is_empty()).count();
    let has_audio = non_empty_audio_chunks > 0 && audio_pcm.is_some();
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
    if has_audio {
        for slice_aud in &audio_slices {
            if slice_aud.is_empty() {
                continue;
            }
            let aud_sz = slice_aud.len() as u32;
            movi_payload_bytes = movi_payload_bytes
                .saturating_add(8)
                .saturating_add(aud_sz)
                .saturating_add(aud_sz % 2);
        }
    }

    let total_index_entries = sizes.len() + if has_audio { non_empty_audio_chunks } else { 0 };
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
    f.write_all(&usec_per_frame_u32.to_le_bytes())?;
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

        if has_audio {
            if let Some(aud_slice) = audio_slices.get(frame_idx) {
                if !aud_slice.is_empty() {
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

/// فحص بنية ملف RIFF/AVI واستخراج عدد الإطارات الصالحة (`00dc`) داخل قائمة `movi` بأمان (VID-009)
/// يعيد عدد الإطارات الصالحة (>= 0)، أو رمز خطأ سالب عند تلف الحاوية.
pub fn parse_and_validate_avi_frames(bytes: &[u8]) -> Result<Vec<(usize, usize)>, i32> {
    if bytes.len() < 32 {
        return Err(-1);
    }
    if &bytes[0..4] != b"RIFF" || &bytes[8..12] != b"AVI " {
        return Err(-2);
    }

    let declared_riff_size =
        u32::from_le_bytes([bytes[4], bytes[5], bytes[6], bytes[7]]) as usize;
    let container_end = bytes.len().min(declared_riff_size.saturating_add(8));
    if container_end < 24 {
        return Err(-3);
    }

    let mut frames: Vec<(usize, usize)> = Vec::new();
    let mut pos: usize = 12;

    while pos.saturating_add(8) <= container_end {
        let tag = &bytes[pos..pos + 4];
        let chunk_size =
            u32::from_le_bytes([bytes[pos + 4], bytes[pos + 5], bytes[pos + 6], bytes[pos + 7]])
                as usize;
        let data_start = pos + 8;
        let data_end = match data_start.checked_add(chunk_size) {
            Some(e) if e <= container_end => e,
            _ => break, // مقطع مقطوع أو يتجاوز حدود الحاوية
        };

        if tag == b"LIST" {
            if chunk_size >= 4 && data_start + 4 <= data_end {
                let list_type = &bytes[data_start..data_start + 4];
                if list_type == b"movi" {
                    let mut mpos = data_start + 4;
                    while mpos.saturating_add(8) <= data_end {
                        let ctag = &bytes[mpos..mpos + 4];
                        let csize = u32::from_le_bytes([
                            bytes[mpos + 4],
                            bytes[mpos + 5],
                            bytes[mpos + 6],
                            bytes[mpos + 7],
                        ]) as usize;
                        let cstart = mpos + 8;
                        let cend = match cstart.checked_add(csize) {
                            Some(ce) if ce <= data_end => ce,
                            _ => break,
                        };

                        if ctag == b"LIST" && csize >= 4 {
                            // تخطي قوائم rec الفرعية أو الدخول فيها
                            let sub_type = &bytes[cstart..cstart + 4];
                            if sub_type == b"rec " {
                                mpos = cstart + 4;
                                continue;
                            }
                        } else if ctag == b"00dc" && csize >= 8 {
                            if bytes[cstart..cstart + 8] == PNG_SIGNATURE {
                                frames.push((cstart, cend));
                            }
                        }

                        let padded = csize.saturating_add(csize & 1);
                        mpos = match cstart.checked_add(padded) {
                            Some(next_mpos) if next_mpos > mpos => next_mpos,
                            _ => break,
                        };
                    }
                }
            }
        }

        let padded = chunk_size.saturating_add(chunk_size & 1);
        pos = match data_start.checked_add(padded) {
            Some(next_pos) if next_pos > pos => next_pos,
            _ => break,
        };
    }

    Ok(frames)
}

/// فحص ملف AVI من المسار وإرجاع عدد إطارات PNG الصالحة بداخله عبر FFI (VID-009 / VID-018)
#[no_mangle]
pub unsafe extern "C" fn rust_validate_avi_file(path_ptr: *const u8, path_len: usize) -> i32 {
    if path_ptr.is_null() || path_len == 0 || path_len > 4096 {
        return -1;
    }
    let path_bytes = slice::from_raw_parts(path_ptr, path_len);
    let path_str = match std::str::from_utf8(path_bytes) {
        Ok(s) => s,
        Err(_) => return -2,
    };
    let mut file = match File::open(path_str) {
        Ok(f) => f,
        Err(_) => return -3,
    };
    let file_len = match file.metadata() {
        Ok(m) => m.len() as usize,
        Err(_) => return -4,
    };
    if file_len < 32 || file_len > MAX_FFI_BUFFER_BYTES {
        return -5;
    }
    let mut buf = Vec::with_capacity(file_len);
    if file.read_to_end(&mut buf).is_err() {
        return -6;
    }
    match parse_and_validate_avi_frames(&buf) {
        Ok(frames) if !frames.is_empty() => frames.len() as i32,
        Ok(_) => 0,
        Err(code) => code,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_vid001_stereo_vs_mono_fade_timing_and_channel_symmetry() {
        let sample_rate = 1000u32;
        let duration_sec = 3;
        let total_frames = (sample_rate as usize) * duration_sec; // 3000 frames

        // إنشاء إشارة ثابتة بقيمة 20000 لكل من Mono و Stereo
        let mut mono_bytes = vec![0u8; total_frames * 2];
        let mut stereo_bytes = vec![0u8; total_frames * 4];

        let val_bytes = 20000i16.to_le_bytes();
        for f in 0..total_frames {
            mono_bytes[f * 2] = val_bytes[0];
            mono_bytes[f * 2 + 1] = val_bytes[1];

            stereo_bytes[f * 4] = val_bytes[0];
            stereo_bytes[f * 4 + 1] = val_bytes[1];
            stereo_bytes[f * 4 + 2] = val_bytes[0];
            stereo_bytes[f * 4 + 3] = val_bytes[1];
        }

        unsafe {
            let st_mono = rust_process_pcm16_audio(
                mono_bytes.as_mut_ptr(),
                mono_bytes.len(),
                sample_rate,
                1,
                1.0,
                1,
                1,
            );
            let st_stereo = rust_process_pcm16_audio(
                stereo_bytes.as_mut_ptr(),
                stereo_bytes.len(),
                sample_rate,
                2,
                1.0,
                1,
                1,
            );
            assert_eq!(st_mono, 0);
            assert_eq!(st_stereo, 0);
        }

        // التحقق من تطابق كل إطار زمني بين Mono و Stereo، وتطابق القناتين L و R في كل إطار
        for f in 0..total_frames {
            let m_sample = i16::from_le_bytes([mono_bytes[f * 2], mono_bytes[f * 2 + 1]]);
            let s_left = i16::from_le_bytes([stereo_bytes[f * 4], stereo_bytes[f * 4 + 1]]);
            let s_right = i16::from_le_bytes([stereo_bytes[f * 4 + 2], stereo_bytes[f * 4 + 3]]);

            assert_eq!(
                s_left, s_right,
                "Stereo L and R must have identical gain at frame {}",
                f
            );
            assert_eq!(
                m_sample, s_left,
                "Mono and Stereo frame {} must have identical fade timing",
                f
            );
        }

        // بداية Fade-in عند الإطار 0 يجب أن تكون 0، ونهاية Fade-out عند الإطار الأخير يجب أن تكون 0
        let first_stereo = i16::from_le_bytes([stereo_bytes[0], stereo_bytes[1]]);
        let mid_stereo = i16::from_le_bytes([stereo_bytes[1500 * 4], stereo_bytes[1500 * 4 + 1]]);
        let last_stereo = i16::from_le_bytes([
            stereo_bytes[(total_frames - 1) * 4],
            stereo_bytes[(total_frames - 1) * 4 + 1],
        ]);
        assert_eq!(first_stereo, 0);
        assert_eq!(mid_stereo, 20000);
        assert_eq!(last_stereo, 0);
    }

    #[test]
    fn test_vid005_resample_and_mix_different_sample_rates() {
        let master_rate = 48000u32;
        let overlay_rate = 24000u32;
        // 1 ثانية Master Stereo (48000 إطار)
        let mut master = vec![0u8; 48000 * 4];
        // 0.5 ثانية Overlay Mono عند 24000 Hz (12000 عينة) بقيمة 10000
        let mut overlay = vec![0u8; 12000 * 2];
        let v = 10000i16.to_le_bytes();
        for i in 0..12000 {
            overlay[i * 2] = v[0];
            overlay[i * 2 + 1] = v[1];
        }

        unsafe {
            let res = rust_mix_pcm16_overlay_resampled(
                master.as_mut_ptr(),
                master.len(),
                overlay.as_ptr(),
                overlay.len(),
                master_rate,
                2,
                overlay_rate,
                1,
                0.25, // يبدأ عند 0.25 ثانية (الإطار 12000) ويمتد لـ 0.5 ثانية (حتى الإطار 36000)
                1.0,
            );
            assert_eq!(res, 0);
        }

        // قبل 0.25 ثانية (الإطار 11999) يجب أن يكون الصفر
        let before = i16::from_le_bytes([master[11999 * 4], master[11999 * 4 + 1]]);
        // داخل منطقة المزج (الإطار 20000) يجب أن يكون 10000 في القناتين
        let inside_l = i16::from_le_bytes([master[20000 * 4], master[20000 * 4 + 1]]);
        let inside_r = i16::from_le_bytes([master[20000 * 4 + 2], master[20000 * 4 + 3]]);
        // بعد انتهاء الـ 0.5 ثانية (الإطار 36005) يجب أن يعود للصفر
        let after = i16::from_le_bytes([master[36005 * 4], master[36005 * 4 + 1]]);

        assert_eq!(before, 0);
        assert_eq!(inside_l, 10000);
        assert_eq!(inside_r, 10000);
        assert_eq!(after, 0);
    }

    #[test]
    fn test_vid004_and_vid011_nv12_bounds_and_odd_dimensions() {
        let mut rgba = vec![255u8; 16 * 16 * 4];
        let mut nv12 = vec![0u8; (16 * 16 * 3) / 2];

        unsafe {
            // الأبعاد الفردية يجب أن تُرفض برمز -3
            let odd_status = rust_rgba_to_nv12(rgba.as_ptr(), nv12.as_mut_ptr(), 15, 16);
            assert_eq!(odd_status, -3);

            // الأبعاد الزوجية الصحيحة تنجح وتنتج Y=235, U=128, V=128 للأبيض النقي
            let ok_status = rust_rgba_to_nv12(rgba.as_ptr(), nv12.as_mut_ptr(), 16, 16);
            assert_eq!(ok_status, 0);
            assert_eq!(nv12[0], 235);
            assert_eq!(nv12[16 * 16], 128);
            assert_eq!(nv12[16 * 16 + 1], 128);
        }
    }

    #[test]
    fn test_vid009_avi_parser_validation_and_truncation_safety() {
        // إنشاء إطار PNG وهمي بتوقيع PNG صحيح
        let mut fake_png = Vec::from(PNG_SIGNATURE);
        fake_png.extend_from_slice(&[1, 2, 3, 4, 5]); // طول فردي (13 بايت) لاختبار المحاذاة الزوجية
        let mut all_frames = Vec::new();
        all_frames.extend_from_slice(&fake_png);
        all_frames.extend_from_slice(&fake_png);
        let sizes = vec![fake_png.len() as u32, fake_png.len() as u32];

        let tmp_path = "/tmp/test_vid009.avi";
        write_avi_container(tmp_path, &all_frames, &sizes, 720, 1280, 30, None).unwrap();

        let bytes = std::fs::read(tmp_path).unwrap();
        let parsed = parse_and_validate_avi_frames(&bytes).unwrap();
        assert_eq!(parsed.len(), 2);

        // اختبار ملف مقطوع: لا يجوز أن يسبب panic أو قراءة خارج الحدود
        let truncated = &bytes[..bytes.len() - 10];
        let parsed_trunc = parse_and_validate_avi_frames(truncated).unwrap();
        assert!(parsed_trunc.len() <= 2);
        let _ = std::fs::remove_file(tmp_path);
    }
}
