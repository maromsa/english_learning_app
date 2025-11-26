As a World-Class Senior Technical Artist and Game Designer, I understand the vision for a vibrant, optimized, and engaging level selection map. This specification will guide the creation of a stunning 3D magical floating island, ensuring it meets both artistic and technical requirements for mobile platforms.

---

# Main Prompt for AI Generators

Generate a highly stylized, Pixar-like 3D model of a magical floating island, designed as a vibrant level selection map. The island features distinct, interconnected biomes: a lush, verdant green forest with oversized, rounded foliage; a bustling, warm orange market area with small, charming stalls and awnings; a serene, reflective blue ocean cove with gentle waves and stylized corals; a jagged, snow-capped white mountain range with icy peaks; and a mystical, glowing purple magic zone with ethereal particles and glowing runes. A gracefully winding, stylized cobblestone bridge connects these diverse areas. Integrate sparkling, low-poly crystal formations, cascading, stylized waterfalls flowing into the void, detached floating rock formations orbiting the main island, and a majestic, giant central tree with broad, inviting branches and glowing leaves, serving as the island's focal point. The scene is bathed in bright, warm, kid-friendly sunlight, casting soft, inviting shadows and volumetric god rays, with a clear, vibrant skybox. Optimized for mobile platforms, low poly, PBR materials, high detail.

# Technical Specifications

*   **Triangle Count Target**:
    *   **Primary Target**: 15,000 triangles (for the entire main island structure and primary assets).
    *   **LODs Recommended**:
        *   LOD0: 15,000 triangles (for close-up views / active selection)
        *   LOD1: 7,500 - 10,000 triangles (for general map view)
        *   LOD2: 3,000 - 5,000 triangles (for distant/overview map view, if applicable)
    *   *Note*: Instanced vegetation and small props should be optimized with efficient atlases and shared materials.
*   **Texture Resolutions**:
    *   **Main Island/Terrain Atlas**: 2048x2048 or 1024x1024 (Diffuse, Normal, ORM - Occlusion/Roughness/Metallic packed)
    *   **Major Props (Giant Tree, Bridge)**: 1024x1024 (Diffuse, Normal, ORM)
    *   **Smaller Props (Crystals, Stalls, Rocks)**: 512x512 or 256x256 (Atlased where possible)
    *   **Particle Effects (Waterfalls, Magic)**: 128x128 or 64x64 (Diffuse, Alpha)
    *   **Skybox**: 1024x512 or 2048x1024 (Equirectangular)
*   **Material Workflow**:
    *   **PBR (Physically Based Rendering)**: Emphasize a stylized PBR approach. Materials should have clear albedo, roughness, and normal maps. Metallic maps will be used sparingly for specific elements (e.g., crystal facets, market accents).
    *   **Unlit/Emissive**: Employ for glowing elements (magic zone, crystal highlights, giant tree leaves) to enhance the magical feel without complex lighting calculations.
    *   **Vertex Colors**: Can be used for subtle blending on terrain or for specific stylized effects.
*   **File Format recommendations**:
    *   **3D Models**: FBX (.fbx) for static meshes and animations (if any prop has movement). GLB/glTF (.glb/.gltf) for web-based viewers or modern engines.
    *   **Textures**: PNG (.png) for diffuse/albedo (with alpha where needed), TGA (.tga) for normal maps (if specific compression is required), JPG (.jpg) for less critical textures or skyboxes to save space.

# Detailed Scene Description

The magical floating island is a cohesive yet visually distinct world, designed to be easily navigable and inviting.

*   **Breakdown of Geometry**:
    *   **Foreground**: Small, gently bobbing floating rocks in close proximity to the main island, stylized clouds drifting in the lower sky, and subtle particle effects (e.g., shimmering dust, gentle wind wisps) to enhance magic.
    *   **Midground (Main Island)**:
        *   **Island Base**: A stylized, rounded landmass with carved-out sections for the ocean biome, organically shaped cliffs where waterfalls cascade. The underside of the island should show exposed, mossy rock and some glowing magical veins.
        *   **Green Forest Biome**: Dominated by large, fluffy, spherical trees with vibrant green leaves, stylized mushrooms, and winding paths. Ground texture is lush grass.
        *   **Orange Market Biome**: Flat, open area with small, colorful, tent-like stalls, barrels, crates, and warm-toned ground textures (cobblestone or packed earth).
        *   **Blue Ocean Biome**: A cut-out section of the island, filled with clear, stylized blue water, gentle ripples, and simple coral formations near the edge.
        *   **White Snowy Mountain Biome**: Sharp, angular peaks and slopes covered in pristine white snow, with exposed grey rock faces. Minimal, stylized pine trees.
        *   **Purple Magic Biome**: A more abstract, elevated area with glowing purple crystals, swirling magical mist particle effects, and ancient-looking runes etched into the ground.
        *   **Winding Bridge**: A sturdy, stylized cobblestone bridge with rounded arches and low railings, connecting the various biomes smoothly.
        *   **Crystals**: Scattered throughout, especially in the magic and mountain biomes. Low-poly, faceted gems with subtle emissive properties.
        *   **Waterfalls**: Multiple stylized waterfalls, represented by semi-transparent, flowing planes with foamy bases, cascading off the island's edges into the void below.
        *   **Giant Central Tree**: A massive, ancient-looking tree with a broad, gnarled trunk and sprawling branches. Its leaves are large, round, and have a subtle glow, perhaps with a soft, ethereal light emanating from its core.
    *   **Background**: A clear, gradient skybox transitioning from a warm, bright yellow/orange near the horizon to a soft, inviting light blue overhead. Distant, hazy floating landmasses or clouds add depth without drawing focus.
*   **Color Palette**:
    *   **Overall Atmosphere**: Bright, Saturated, Warm
    *   **Sky**: `#FFDDAA` (Warm Horizon) to `#87CEEB` (Sky Blue)
    *   **Green Forest**: `#4CAF50` (Lush Green), `#8BC34A` (Lime Green), `#795548` (Tree Trunk Brown)
    *   **Orange Market**: `#FF9800` (Vibrant Orange), `#FFEB3B` (Sunny Yellow), `#795548` (Wood Brown)
    *   **Blue Ocean**: `#2196F3` (Deep Blue), `#81D4FA` (Light Blue Water), `#4DD0E1` (Turquoise Coral)
    *   **White Snowy Mountain**: `#FFFFFF` (Pure White Snow), `#B0BEC5` (Grey Rock), `#ECEFF1` (Icy Blue Highlights)
    *   **Purple Magic Area**: `#9C27B0` (Vibrant Purple), `#E040FB` (Magenta Glow), `#6A1B9A` (Deep Violet)
    *   **Bridge/Cobblestone**: `#A1887F` (Warm Grey-Brown)
    *   **Giant Tree**: `#4E342E` (Dark Brown Trunk), `#AED581` (Glowing Green Leaves)
    *   **Crystals**: Varied, with emissive highlights (e.g., `#FFC107` Gold, `#03A9F4` Light Blue, `#E040FB` Magenta)
*   **Lighting Setup details**:
    *   **Primary Light Source**: A strong, directional light representing a warm, mid-morning sun. Positioned to cast long, soft shadows that define the island's features and add depth.
    *   **Ambient Light**: A soft, warm ambient light (`#FFFBE6`) to fill in shadows and prevent them from becoming too dark, maintaining the kid-friendly mood.
    *   **Bounce Light**: Subtle, warm bounce light from the terrain and water surfaces to enhance realism and vibrancy.
    *   **Volumetric Lighting**: Gentle volumetric god rays emanating from the sun, especially visible through gaps in the giant tree's canopy or over the magic zone, adding to the magical atmosphere.
    *   **Emissive Lighting**: Specific elements like crystals, the magic zone, and the giant tree's leaves will have emissive properties, contributing to local illumination and magical glow.
    *   **Post-Processing**: Bloom for emissive elements, subtle color grading to enhance warmth and saturation, and a slight vignette to focus attention on the island.

# Variant Prompts

### Luma Genie Specific

"Generate a 3D geometric structure of a stylized, Pixar-esque floating island map. Focus on the distinct spatial arrangement of five interconnected biomes: a rounded green forest plateau, an elevated orange market plaza, a carved-out blue ocean basin, a jagged white snowy mountain peak, and a mystical purple magic zone. Include a winding, structurally sound bridge connecting these areas. Integrate distinct 3D forms for sparkling crystals, cascading waterfalls (represented by flowing planes), individual floating rock formations (separate entities), and a prominent giant central tree acting as the island's highest point. Ensure clear separation and definition of each biome's unique topographical features. Low poly, optimized mesh for mobile."

### Meshy.ai Specific

"Create a clean topology 3D model of a magical floating island level map in a stylized, Pixar-like art style. Prioritize detailed PBR textures for each distinct biome: rich green foliage and earthy ground for the forest, warm cobblestone and canvas for the market, clear blue water and rocky seabed for the ocean, pristine white snow and grey rock for the mountain, and glowing purple energy and ancient stone for the magic area. The winding bridge should have defined cobblestone texture. Include distinct mesh details for faceted crystals with metallic sheen, stylized waterfall planes with alpha transparency, separate floating rock meshes with mossy textures, and a giant central tree with detailed bark and glowing leaf textures. All assets should be optimized for mobile, with efficient UV mapping and material packing."

### Concept Art (Midjourney)

"Wide cinematic shot of a breathtaking, vibrant, Pixar-style magical floating island level selection map, bathed in warm, golden hour sunlight. The island is a tapestry of distinct, colorful biomes: a lush emerald forest, a bustling amber market, a serene sapphire ocean cove, a majestic diamond-white snowy mountain, and a mystical amethyst purple magic zone. A charming, winding bridge gracefully connects these fantastical areas. Sparkling crystals catch the light, ethereal waterfalls cascade into the misty void, and smaller floating rocks drift around the main landmass. A colossal, ancient tree with glowing leaves stands proudly at the island's heart, its branches reaching towards a vibrant, gradient sky filled with soft, stylized clouds. The mood is enchanting, inviting, and full of wonder. High detail, vivid colors, volumetric light, depth of field, 16:9 aspect ratio."