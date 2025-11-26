As a Senior Technical Artist and Game Designer, I've taken your vision for the "Magic Items Shop World" and crafted a comprehensive technical specification and prompt set. This document aims to guide AI generation tools and development teams in bringing your stylized, cozy magical shop to life, optimized for mobile platforms.

---

# Main Prompt for AI Generators

A cozy, whimsical, stylized 3D interior of an arcane magic items shop, rendered in a vibrant Pixar-like art style. The scene features antique wooden shelves laden with an assortment of enchanted artifacts: slender magic wands, shimmering crystals emitting soft glows (purple, blue, gold), glass potion bottles filled with swirling, luminescent liquids, and ancient, ornate enchanted books. A sturdy wooden shop counter occupies the foreground. Large arched windows in the background reveal a mystical, deep blue-purple starry night sky. The overall lighting is warm and magical, with prominent soft glow effects emanating from the magical items, creating a dreamy, inviting atmosphere. Low-poly, optimized for mobile platforms, fantasy, magical, enchanted, inviting, vibrant, detailed.

# Technical Specifications

*   **Triangle Count Target**: Maximum 8,000 triangles for the entire scene, including all props and environment geometry.
*   **Texture Resolutions**:
    *   Main Environment Atlas (walls, floor, ceiling, counter, shelves): 1024x1024 to 2048x1024 (if rectangular).
    *   Individual Props Atlas (wands, crystals, bottles, books): 512x512 to 1024x1024, or individual 256x256 textures for unique hero props.
    *   Emissive Maps: 256x256 to 512x512 for glowing elements, integrated into prop atlases where possible.
    *   Prioritize texture atlasing to minimize draw calls and optimize performance on mobile devices.
*   **Material Workflow**: PBR (Physically Based Rendering) with a clean, un-grungy aesthetic. Emissive maps are critical for the glowing liquids and crystals. Use simple Metallic/Roughness maps. Alpha masks for subtle dust motes or window effects are acceptable. Avoid complex shaders or transparency where simple alpha clipping can suffice.
*   **File Format recommendations**: FBX (.fbx) for robust engine import, or GLTF/GLB (.gltf/.glb) for modern web and engine compatibility, ensuring embedded textures for easy portability.

# Detailed Scene Description

*   **Geometry Breakdown**:
    *   **Foreground**: A sturdy, slightly worn wooden shop counter positioned centrally or slightly to one side, perhaps with a few larger, intriguing items like an open spell book or a prominent, faceted crystal. The floor should be visible, textured with warm wooden planks or smooth flagstones.
    *   **Midground**: The core of the shop, featuring several multi-tiered wooden shelves meticulously organized with an array of magical wares. This includes an assortment of slender, ornate magic wands (some mounted, some lying flat), various sizes of sparkling crystals (some clustered, some standalone), numerous glass potion bottles ranging from small vials to larger decanters, each containing uniquely colored, glowing liquids, and ancient, leather-bound enchanted books with subtle magical glyphs.
    *   **Background**: The back wall, prominently featuring one or two large, arched or ornate windows. Through these windows, a vibrant, deep blue-purple starry night sky is visible, adding depth and a sense of wonder. A subtle, textured wall surface (stone, plaster, or carved wood) should be present behind the shelves.
*   **Color Palette**:
    *   **Warm Woods**: `#8B4513` (Saddle Brown), `#A0522D` (Sienna) - for shelves, counter, floor.
    *   **Magical Glows**: `#8A2BE2` (Blue Violet), `#4169E1` (Royal Blue), `#FFD700` (Gold), `#FF69B4` (Hot Pink) - for potion liquids, crystal luminescence, and magical effects.
    *   **Ambient Warmth**: `#F0E68C` (Khaki), `#FFE4B5` (Moccasin) - general warm fill light.
    *   **Starry Night**: `#191970` (Midnight Blue), `#483D8B` (Dark Slate Blue) - for the sky.
    *   **Accents**: `#C0C0C0` (Silver), `#DAA520` (Goldenrod) - for metallic details on wands, book clasps, or counter trim.
*   **Lighting Setup details**:
    *   **Primary Light**: A soft, warm, omnidirectional ambient light source provides a base illumination, mimicking a hidden magical lamp or general enchantments within the shop.
    *   **Emissive Lighting**: The primary source of visual interest and mood. All magical items (potion liquids, crystals, specific runes on books/wands) should have prominent emissive properties, casting soft, colored light into their immediate surroundings. These glows should be vibrant but not overpowering, creating a dreamlike, inviting atmosphere.
    *   **Window Light**: A subtle, cool, ethereal light emanating from the starry night sky outside the windows, providing a gentle backlight and contrast to the warm interior.
    *   **Volumetric Effects**: Introduce subtle, warm-toned volumetric fog or dust motes, catching the light from the glowing items, enhancing the magical ambiance and depth.
    *   **Shadows**: Soft, diffused shadows, avoiding harsh lines, to maintain the cozy and inviting aesthetic. Ambient occlusion should be baked or screen-space to enhance depth without adding sharp shadows.

# Variant Prompts

### Luma Genie Specific

A cozy, stylized 3D interior environment of a magic shop. Define the main structural elements: a rectangular room with a prominent wooden counter in the foreground, multi-tiered wooden shelves lining the midground walls, and large arched windows in the background. Populate shelves with distinct placeholder shapes for magic wands, potion bottles, sparkling crystals, and enchanted books. Emphasize depth, spatial arrangement, and clear object separation for structure generation.

### Meshy.ai Specific

Generate a stylized, low-poly 3D model of a magic items shop interior, optimized for mobile. Model clean, solid geometry for wooden shelves, shop counter, walls, and floor. Apply clean PBR textures for wood grain, polished glass, and subtle metallic elements. Clearly define emissive channels for glowing potion liquids (purple, blue, gold) and sparkling crystals. Ensure sharp, readable textures for enchanted book covers and wand details. Render with soft, warm lighting and prominent emissive glows.

### Concept Art (Midjourney)

Concept art: A whimsical, Pixar-style magical items shop interior at night. The scene exudes a warm, inviting, and enchanting atmosphere. Focus on volumetric soft glows emanating from hundreds of unique magical artifacts: glowing potion bottles, shimmering crystals, intricate wands, and ancient spellbooks, all meticulously arranged on antique wooden shelves. A sturdy, inviting shop counter occupies the foreground. Large, ornate windows in the background reveal a breathtaking, deep purple-blue starry night sky. Emphasize dreamy, enchanted lighting, cinematic composition, and a sense of wonder, fantasy illustration.