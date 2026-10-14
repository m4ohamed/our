// rust_video_engine/src/lib.rs
// محرك Rust مستلهم من معمارية FilmCraft و EffectCraft (مجموعة ArtCraft مفتوحة المصدر)
// يضم:
// 1. نظام التوقيت الصحيح الخالي من الانجراف (Exact Integer Ticks: 254,016,000,000 ticks/sec)
// 2. استيفاء الـ Keyframes المتقدم (Hold, Linear, Cubic Bezier, Auto-Bezier Catmull-Rom, Elastic)
// 3. مصفوفات تصحيح الألوان السينمائية (Lumetri-style Procedural Color Grading Matrix)
// 4. دمج الإطارات وتوليد حاوية الفيديو القياسية RIFF/AVI عبر C-ABI FFI

use std::f64::consts::PI;
use std::fs::File;
use std::io::{Seek, SeekFrom, Write};
use std::slice;

/// عدد النبضات الزمنية في الثانية الواحدة كما في محرك FilmCraft
/// يقبل القسمة بدون باقٍ على كافة معدلات الإطارات (23.976, 24, 25, 29.97, 30, 50, 59.94, 60)
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

/// تحويل الثواني إلى نبضات صحيحة (Exact Integer Ticks) لمنع أي انجراف في الفريمات
#[no_mangle]
pub extern "C" fn rust_seconds_to_ticks(seconds: f64) -> i64 {
    (seconds * (TICKS_PER_SECOND as f64)).round() as i64
}

/// تحويل النبضات الصحيحة إلى ثوانٍ
#[no_mangle]
pub extern "C" fn rust_ticks_to_seconds(ticks: i64) -> f64 {
    (ticks as f64) / (TICKS_PER_SECOND as f64)
}

/// تطبيق منحنى الحركة (Easing) في Rust بسرعة C-ABI
/// easing_type: 0 = Linear, 1 = EaseIn, 2 = EaseOut, 3 = EaseInOut, 4 = ElasticOut, 5 = Hold, 6 = AutoBezier
#[no_mangle]
pub extern "C" fn rust_apply_easing(t: f64, easing_type: i32) -> f64 {
    let clamped = t.clamp(0.0, 1.0);
    match easing_type {
        1 => clamped * clamped * clamped,
        2 => {
            let inv = 1.0 - clamped;
            1.0 - inv * inv * inv
        }
        3 => {
            if clamped < 0.5 {
                4.0 * clamped * clamped * clamped
            } else {
                let f = -2.0 * clamped + 2.0;
                1.0 - (f * f * f) / 2.0
            }
        }
        4 => {
            if clamped == 0.0 || clamped == 1.0 {
                clamped
            } else {
                let c4 = (2.0 * PI) / 3.0;
                2.0_f64.powf(-10.0 * clamped) * ((clamped * 10.0 - 0.75) * c4).sin() + 1.0
            }
        }
        5 => {
            // Hold Keyframe (كما في Premiere / FilmCraft و After Effects / EffectCraft)
            if clamped < 1.0 { 0.0 } else { 1.0 }
        }
        6 => {
            // Smoothstep / Auto-Bezier continuous curve
            clamped * clamped * (3.0 - 2.0 * clamped)
        }
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

/// حساب مصفوفة تصحيح الألوان 4x5 (20 عنصراً) بأسلوب Lumetri Color في FilmCraft
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

    let gain = 2.0_f64.powf(exposure.clamp(-2.0, 2.0));
    let c = (1.0 + contrast.clamp(-0.8, 1.5)).max(0.1);
    let s = (1.0 + saturation.clamp(-1.0, 1.5)).max(0.0);
    let temp = temperature.clamp(-1.0, 1.0) * 30.0;
    let fade = faded_film.clamp(0.0, 0.5) * 45.0;

    // معاملات الإضاءة القياسية Rec.709 كما في FilmCraft
    let lum_r = 0.2126;
    let lum_g = 0.7152;
    let lum_b = 0.0722;

    let sr = (1.0 - s) * lum_r;
    let sg = (1.0 - s) * lum_g;
    let sb = (1.0 - s) * lum_b;

    let scale = gain * c;
    let offset = (1.0 - c) * 128.0 + fade;

    // Row 0 (Red)
    out[0] = scale * (sr + s);
    out[1] = scale * sg;
    out[2] = scale * sb;
    out[3] = 0.0;
    out[4] = offset + temp;

    // Row 1 (Green)
    out[5] = scale * sr;
    out[6] = scale * (sg + s);
    out[7] = scale * sb;
    out[8] = 0.0;
    out[9] = offset;

    // Row 2 (Blue)
    out[10] = scale * sr;
    out[11] = scale * sg;
    out[12] = scale * (sb + s);
    out[13] = 0.0;
    out[14] = offset - temp;

    // Row 3 (Alpha)
    out[15] = 0.0;
    out[16] = 0.0;
    out[17] = 0.0;
    out[18] = 1.0;
    out[19] = 0.0;
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

    match write_avi_container(path_str, all_frames, sizes, width, height, fps) {
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
) -> std::io::Result<()> {
    let mut f = File::create(path)?;
    let num_frames = sizes.len() as u32;
    let usec_per_frame = if fps > 0 { 1_000_000 / fps } else { 66_666 };

    f.write_all(b"RIFF")?;
    let riff_size_pos = f.stream_position()?;
    f.write_all(&0u32.to_le_bytes())?;
    f.write_all(b"AVI ")?;

    f.write_all(b"LIST")?;
    f.write_all(&192u32.to_le_bytes())?;
    f.write_all(b"hdrl")?;

    f.write_all(b"avih")?;
    f.write_all(&56u32.to_le_bytes())?;
    f.write_all(&usec_per_frame.to_le_bytes())?;
    f.write_all(&(width * height * 3 * fps).to_le_bytes())?;
    f.write_all(&0u32.to_le_bytes())?;
    f.write_all(&0x10u32.to_le_bytes())?;
    f.write_all(&num_frames.to_le_bytes())?;
    f.write_all(&0u32.to_le_bytes())?;
    f.write_all(&1u32.to_le_bytes())?;
    f.write_all(&(width * height * 4).to_le_bytes())?;
    f.write_all(&width.to_le_bytes())?;
    f.write_all(&height.to_le_bytes())?;
    f.write_all(&[0u8; 16])?;

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
    f.write_all(&fps.to_le_bytes())?;
    f.write_all(&0u32.to_le_bytes())?;
    f.write_all(&num_frames.to_le_bytes())?;
    f.write_all(&(width * height * 4).to_le_bytes())?;
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
    f.write_all(&(width * height * 4).to_le_bytes())?;
    f.write_all(&[0u8; 16])?;

    f.write_all(b"LIST")?;
    let movi_size_pos = f.stream_position()?;
    f.write_all(&0u32.to_le_bytes())?;
    let movi_start = f.stream_position()?;
    f.write_all(b"movi")?;

    let mut offsets = Vec::with_capacity(sizes.len());
    let mut cursor = 0usize;
    for &sz in sizes {
        let chunk_pos = f.stream_position()? - movi_start;
        offsets.push((chunk_pos as u32, sz));
        f.write_all(b"00dc")?;
        f.write_all(&sz.to_le_bytes())?;
        let end = cursor + (sz as usize);
        f.write_all(&all_frames[cursor..end])?;
        if sz % 2 == 1 {
            f.write_all(&[0u8])?;
        }
        cursor = end;
    }
    let movi_end = f.stream_position()?;

    f.write_all(b"idx1")?;
    f.write_all(&((offsets.len() * 16) as u32).to_le_bytes())?;
    for (offset, sz) in offsets {
        f.write_all(b"00dc")?;
        f.write_all(&0x10u32.to_le_bytes())?;
        f.write_all(&offset.to_le_bytes())?;
        f.write_all(&sz.to_le_bytes())?;
    }

    let file_end = f.stream_position()?;
    f.seek(SeekFrom::Start(riff_size_pos))?;
    f.write_all(&((file_end - 8) as u32).to_le_bytes())?;
    f.seek(SeekFrom::Start(movi_size_pos))?;
    f.write_all(&((movi_end - movi_start) as u32).to_le_bytes())?;
    Ok(())
}
