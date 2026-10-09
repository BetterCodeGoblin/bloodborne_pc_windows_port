// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

namespace Vulkan::UiComposition {

enum class Background { None, Copy, Temporal };

// UI composition must not require scene depth/camera or an active FSR context.
constexpr Background Choose(bool scaled, bool ui_draw, bool scene_ready, bool fsr_active) {
    if (!scaled || !ui_draw) {
        return Background::None;
    }
    return scene_ready && fsr_active ? Background::Temporal : Background::Copy;
}

// UI canvas width in game coordinates: 1920, or for an output wider than 16:9 the HUD canvas
// scripts/patches.py widens (hud_width: 1080 * aspect in multiples of 64; 2560 at 21:9). Its
// height stays 1080, so the canvas scales uniformly to the output (output height / 1080).
inline uint32_t CanvasWidth() {
    static const uint32_t width = [] {
        unsigned w = 0, h = 0;
        const char* res = std::getenv("BB_OUTPUT_RES");
        if (!res || std::sscanf(res, "%ux%u", &w, &h) != 2 || !h || w * 9 <= h * 16) {
            return 1920u;
        }
        const auto hud = uint32_t(std::lround(1080.0 * w / h / 64.0)) * 64u;
        return hud > 1920u ? hud : 1920u;
    }();
    return width;
}

inline bool NativeViewport(float width, float height) {
    return std::abs(std::abs(width) - float(CanvasWidth())) < 0.5f &&
           std::abs(std::abs(height) - 1080.0f) < 0.5f;
}

// Scaleform draws, including the first stencil/movie pass. A native-size viewport
// alone also matches every fullscreen post pass when guest targets stay at 1080p.
constexpr bool MovieShader(uint64_t hash) {
    return hash == 0x34e8a281 || hash == 0x81d336ce || hash == 0x09957251 ||
           hash == 0x24042a9b || hash == 0xa400228b;
}

inline std::array<float, 2> Scale(uint32_t guest_width, uint32_t guest_height,
                                uint32_t output_width, uint32_t output_height,
                                bool native_coordinates) {
    return {float(output_width) / float(native_coordinates ? CanvasWidth() : guest_width),
            float(output_height) / float(native_coordinates ? 1080 : guest_height)};
}

} // namespace Vulkan::UiComposition
