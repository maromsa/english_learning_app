As a World-Class Senior Technical Artist and Game Designer, I've taken your vision for an "Ocean Underwater World" and meticulously crafted a comprehensive technical specification and prompt set. This document will guide the creation of a stunning, optimized 3D asset suitable for mobile platforms, embodying a vibrant, Pixar-like aesthetic.

---

# Main Prompt for AI Generators

Generate a vibrant, stylized, and serene underwater coral reef scene, reminiscent of Pixar animation. The environment features a richly detailed, low-poly coral ecosystem brimming with life. Dominant elements include diverse, colorful coral formations in shades of coral pinks, warm oranges, and soft purples, interspersed with gently swaying sea plants like kelp and various seaweeds in lush greens and teals. A school of stylized, friendly fish, a scattering of starfish, and ornate shells adorn the sandy seabed, which exhibits a subtle, rippled texture. The entire scene is bathed in soft, volumetric blue lighting filtering down from the surface, creating ethereal light shafts (God rays) and delicate caustics dancing across the ocean floor. The background transitions into an open, ethereal blue water vista, hinting at boundless depths. The overall mood is whimsical, inviting, and tranquil, optimized for mobile performance with a target triangle count under 10,000.

# Technical Specifications

*   **Triangle Count Target**: Up to 10,000 triangles for the entire scene, with individual hero assets (e.g., a large coral formation, a school of fish) optimized for efficient rendering.
*   **Texture Resolutions**:
    *   **Primary Environment Atlas**: 1024x1024 (for coral, sand, rocks, kelp)
    *   **Hero Assets (e.g., specific fish species, unique shells)**: 512x512 or 256x256
    *   **Decals/Detail Normals (if used)**: 128x128
    *   **Overall Scene Optimization**: Prioritize texture atlasing to reduce draw calls.
*   **Material Workflow**: PBR Metallic-Roughness workflow.
    *   **Channels**: Albedo (Base Color), Normal, Roughness, Metallic (primarily for specific reflective elements like shells or fish scales, otherwise 0), Ambient Occlusion.
    *   **Stylization Note**: Roughness values should be carefully balanced to achieve a soft, diffuse look consistent with the Pixar-like aesthetic, avoiding overly sharp reflections. Metallic values should be subtle.
*   **File Format Recommendations**:
    *   **3D Model**: FBX (.fbx) for mesh and animation data (if any swaying is pre-baked).
    *   **Textures**: PNG (.png) for color and alpha, TGA (.tga) for normal maps to preserve detail and reduce compression artifacts.

# Detailed Scene Description

*   **Breakdown of Geometry**:
    *   **Foreground**:
        *   **Coral Clusters**: Intricately modeled, low-poly brain coral, fan coral, and branching coral in varying sizes, exhibiting vibrant, saturated colors.
        *   **Marine Life**: A few larger, detailed starfish on the sand, scattered decorative shells (conch, scallop) with subtle normal map details. Small, individually animated fish swimming slowly.
        *   **Seabed**: A gently undulating sandy floor with a subtle ripple pattern, revealing hints of scattered pebbles or detritus.
    *   **Midground**:
        *   **Larger Coral Formations**: More expansive coral structures providing visual anchors, perhaps a small archway or overhang.
        *   **Sea Plants**: Taller kelp stalks with broad, swaying leaves, and clusters of seaweed providing vertical interest and motion.
        *   **Fish Schools**: A small school of stylized fish (e.g., clownfish, angelfish types) swimming in gentle patterns, potentially with simple vertex animation for movement.
        *   **Light Interaction**: Prominent light shafts (God rays) cutting through the water, illuminating particulate matter and casting soft shadows.
    *   **Background**:
        *   **Open Water**: A gradient of deep to lighter blues, becoming less saturated and more diffuse towards the horizon.
        *   **Distant Silhouettes**: Very faint, stylized silhouettes of distant rock formations or even larger, indistinct marine life (e.g., a distant whale or manta ray) to suggest scale and depth.
        *   **Atmospheric Effect**: A subtle volumetric fog effect to enhance the underwater depth perception.

*   **Color Palette**:
    *   **Blues & Teals (Water/Lighting)**:
        *   `#0A2463` (Deep Ocean Blue - Background)
        *   `#28536B` (Mid-Water Teal - Ambient)
        *   `#8FC1E3` (Soft Sky Blue - Light Source/Highlights)
    *   **Coral Pinks & Oranges (Coral)**:
        *   `#FF6F61` (Vibrant Coral Pink)
        *   `#FFB347` (Soft Peach Orange)
        *   `#C795E0` (Lavender Purple - Accent Coral)
    *   **Greens (Sea Plants)**:
        *   `#5CB85C` (Lush Kelp Green)
        *   `#7FB069` (Subtle Seaweed Green)
    *   **Yellows & Browns (Sand/Shells)**:
        *   `#F7DCB4` (Warm Sandy Yellow)
        *   `#A07855` (Light Brown - Shell Accents)
    *   **Overall**: The palette should be highly saturated but harmonious, reflecting a cheerful and inviting underwater world.

*   **Lighting Setup Details**:
    *   **Primary Light Source**: A single, directional light from directly above, simulating the sun, with a strong blue tint.
    *   **Volumetric Fog/Light Shafts**: A volumetric fog pass to create visible light shafts (God rays) extending from the surface down into the scene. This should be a soft, ethereal blue.
    *   **Caustics**: A subtle animated texture projected onto the seabed and upward-facing surfaces to simulate dancing light patterns from the water's surface.
    *   **Ambient Lighting**: A soft, cool blue ambient light to fill in shadows and maintain the underwater aesthetic.
    *   **Subsurface Scattering (Optional, for hero assets)**: A minimal amount on coral and some plant leaves to give them a soft, translucent quality, enhancing the "Pixar-like" feel.
    *   **Post-Processing**: Light bloom on highlights, subtle color grading to enhance blues and teals, and a touch of chromatic aberration for artistic flair.

# Variant Prompts

1.  **Luma Genie Specific**:
    "Generate a low-poly stylized 3D environment: an underwater coral reef scene. Focus on object placement and structural integrity. Include distinct coral formations (brain, fan, branching), swaying kelp forests, scattered starfish, and shells on a rippled sand bed. Incorporate a school of small, stylized fish. The scene should be arranged with clear foreground, midground, and background elements, illuminated by soft, top-down blue volumetric light shafts, optimized for mobile performance."

2.  **Meshy.ai Specific**:
    "Create a low-poly 3D model of a stylized underwater coral reef scene. Emphasize geometric detail for vibrant coral textures (pink, orange, purple), detailed sea plant meshes (green, teal), and distinct marine creature forms (fish, starfish, shells). The sand texture on the seabed should be clearly defined. Ensure clean topology for efficient texturing using PBR workflow (Albedo, Normal, Roughness, AO) and a final triangle count under 10,000 for mobile optimization. Lighting should suggest soft, filtering blue light from above."

3.  **Concept Art (Midjourney)**:
    "A vibrant, stylized Pixar-esque underwater coral reef, teeming with life. Soft, volumetric blue light shafts pierce the water, illuminating colorful, whimsical coral formations in pinks, oranges, and purples. Lush green kelp sways gently. Friendly, cartoonish fish swim in schools. Detailed starfish and shells rest on a sun-dappled sandy seabed. The atmosphere is serene, magical, and inviting. High detail, award-winning animation still, wide shot, cinematic composition, golden hour underwater lighting. --ar 16:9 --v 5.2"