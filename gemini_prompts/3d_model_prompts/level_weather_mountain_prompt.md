As a World-Class Senior Technical Artist and Game Designer, I've taken your concept for a "Weather/Seasons Mountain World" and expanded it into a comprehensive technical specification and prompt set. This document aims to provide clear guidance for AI asset generation tools while ensuring the output aligns with your artistic vision and technical constraints for mobile platforms.

---

# Main Prompt for AI Generators

Generate a highly stylized, Pixar-esque 3D mountain scene, optimized for mobile platforms, depicting diverse weather elements. The focal point is a cozy, weathered timber observation cabin or small lodge, nestled on a snowy incline, with a winding, snow-covered mountain path leading up to it. Dominating the background are majestic, jagged snow-capped peaks, partially obscured by soft, billowing cumulus clouds. The foreground features scattered, snow-laden stylized pine trees with gently drooping branches. The overall lighting is bright, clear, and serene, evoking a crisp, cool alpine atmosphere with soft, natural shadows and subtle volumetric haze, emphasizing pristine whites, cool light blues, and muted grays. Focus on soft, inviting textures for snow, rustic wood for the cabin, and stylized, simplified rock formations.

# Technical Specifications

*   **Triangle Count Target**:
    *   **Scene (Overall)**: Max 10,000 triangles (for a single hero asset or highly optimized scene segment). This implies heavy use of instancing, simplified geometry, and baked details where possible.
    *   **Key Individual Assets (e.g., Cabin)**: ~1,500 - 2,500 triangles.
    *   **Trees (Individual)**: ~200 - 500 triangles (with potential for LODs).
*   **Texture Resolutions**:
    *   **Main Scene Elements (Terrain, Cabin)**: 1024x1024 pixels.
    *   **Mid-ground Elements (Trees, Rocks)**: 512x512 pixels.
    *   **Minor Details/Atlases**: 256x256 pixels.
    *   *Recommendation*: Utilize texture atlases for multiple small assets to reduce draw calls.
*   **Material Workflow**:
    *   **Optimized PBR (Physically Based Rendering)**: Base Color (Albedo), Normal Map, Roughness, and Ambient Occlusion. Metallic maps are likely unnecessary for this stylized, natural scene.
    *   **Shader Complexity**: Aim for a lightweight, mobile-friendly shader. Consider baking lighting into vertex colors or the albedo map for static elements to further reduce runtime calculations.
    *   **Transparency**: Alpha testing for snow-covered tree branches (if not fully modeled) and clouds.
*   **File Format Recommendations**:
    *   **.FBX**: Industry standard for 3D model interchange, supports meshes, materials, and animations.
    *   **.glTF (GL Transmission Format)**: Excellent for web and mobile, highly optimized, supports PBR materials.
    *   **.OBJ**: Simple mesh data, good for basic geometry, but requires separate material files.

# Detailed Scene Description

*   **Breakdown of the Geometry**:
    *   **Foreground**:
        *   **Mountain Path**: A gently winding, snow-covered path, subtly sculpted into the terrain, showing a clear, traversable route. Minimal, stylized rock outcrops peek through the snow.
        *   **Cabin/Observation Point**: A small, charming, single-story structure. Made of stylized, weathered timber logs or planks, with a steeply sloped roof heavily laden with soft, powdery snow. A small chimney with a wisp of smoke, and a single, warmly lit window suggesting coziness within.
        *   **Trees**: A few stylized pine or fir trees, heavily blanketed with snow on their branches, strategically placed to frame the path and cabin.
    *   **Midground**:
        *   **Rolling Hills**: Gently undulating, snow-covered hills extending from the foreground, leading towards the higher peaks.
        *   **Dense Forest**: A stylized forest of snow-covered pine trees, appearing denser and slightly smaller than the foreground trees, indicating distance.
        *   **Subtle Details**: Perhaps a hint of a frozen stream or a small, ice-covered pond reflecting the sky.
    *   **Background**:
        *   **Snow-capped Peaks**: Grand, imposing, yet stylized mountain ranges. Their sharp, angular forms are softened by thick layers of pristine snow.
        *   **Clouds**: Volumetric, soft, and billowy cumulus clouds partially wrap around the mountain peaks, adding depth and a sense of dynamic weather.
*   **Color Palette**:
    *   **Snow**: `#F8F8FF` (Ghost White) with subtle variations towards `#E0FFFF` (Light Cyan) in shadowed areas.
    *   **Sky/Ambient Light**: `#ADD8E6` (Light Blue) for clear sky, transitioning to `#B0E0E6` (Powder Blue) for distant haze.
    *   **Mountain Rock (Exposed)**: `#A9A9A9` (Dark Gray) for near rocks, fading to `#B0C4DE` (Light Steel Blue) for distant peaks under atmospheric perspective.
    *   **Cabin Wood**: `#D2B48C` (Tan) for weathered timber, with darker accents like `#8B4513` (Saddle Brown) for trim or exposed structural elements.
    *   **Pine Trees (Needles)**: Desaturated `#3CB371` (Medium Sea Green) visible through snow, giving a hint of life.
    *   **Cabin Window Light (Emissive)**: `#FFD700` (Gold) or `#FFA500` (Orange) for a warm, inviting glow.
*   **Lighting Setup Details**:
    *   **Key Light (Sun)**: A strong, directional light source simulating a bright, clear midday sun. Positioned to cast long, soft shadows, enhancing depth and form.
    *   **Fill Light (Sky/Ambient)**: A soft, cool blue ambient light to lift shadows and simulate indirect sky illumination, maintaining clarity.
    *   **Volumetric Elements**: Subtle volumetric fog or haze in the mid-ground and background to enhance atmospheric perspective and give a sense of crisp, cold air.
    *   **Reflections**: Minimal, soft reflections on snowy surfaces and ice, contributing to the sense of a bright, reflective environment.
    *   **Shadows**: Soft, slightly diffused shadows to match the stylized aesthetic, avoiding harsh, pixelated edges.

# Variant Prompts

### Luma Genie Specific

"Generate a 3D model of a stylized, Pixar-like alpine mountain scene. Feature a central, rustic wooden observation cabin with a snow-laden roof, positioned on a gentle snowy slope. Integrate a winding, low-poly mountain path leading to the cabin. Surround the cabin with 3-5 distinct, snow-covered pine trees. In the background, sculpt several large, jagged snow-capped peaks partially enveloped by soft, volumetric clouds. Ensure clear structural definition for all elements, focusing on clean topology suitable for mobile optimization."

### Meshy.ai Specific

"Create a low-polygon 3D asset of a stylized, mobile-optimized mountain winter scene. The primary geometry should include a snow-covered terrain, a detailed yet simple wooden cabin with snow on its roof, and several snow-dusted pine trees. For texturing, apply PBR materials: a base color map for snow (`#F8F8FF`), weathered wood (`#D2B48C`), and desaturated green tree foliage (`#3CB371`). Generate normal maps for subtle rock details and wood grain. Ensure clean UVs and baked ambient occlusion for enhanced visual depth, targeting a crisp, clear alpine look."

### Concept Art (Midjourney)

"Illustrate a serene, Pixar-style mountain landscape at midday, bathed in bright, clear winter light. The composition features a cozy, rustic wooden cabin nestled on a snow-covered slope in the midground, with a winding path leading to it. Lush, snow-laden pine trees frame the foreground. Majestic, sharply defined snow-capped peaks dominate the background, partially obscured by soft, painterly cumulus clouds. The mood is tranquil and inviting, with a color palette dominated by pristine whites, cool light blues, and muted grays, emphasized by soft, volumetric lighting and gentle shadows. Highly detailed, atmospheric, high resolution."