As a Senior Technical Artist and Game Designer, I understand the delicate balance between visual fidelity, performance, and artistic vision, especially for mobile platforms with a "Pixar-like" stylized aesthetic. Your concept of a "Fruit Market World" is rich with potential, promising a vibrant and inviting experience.

Below is a comprehensive technical specification and prompt set designed to guide the creation of this charming scene, ensuring it meets both artistic goals and performance targets.

---

# Main Prompt for AI Generators

Generate a vibrant, stylized Pixar-like 3D environment depicting an inviting early morning fruit market square. Multiple rustic wooden market stalls, painted in cheerful, complementary colors like robin's egg blue, sunny yellow, and warm red, are arranged in a gentle semi-circle. Each stall is overflowing with meticulously arranged, brightly colored, fresh produce: glossy red apples, ripe yellow bananas, vibrant orange oranges, and lush purple and green grapes, all rendered with a soft, appealing cartoon aesthetic. The ground is a mix of worn, slightly irregular cobblestones and weathered wooden planks. Overhead, simple, hand-painted market signs with whimsical typography indicate fruit types. The scene is bathed in a warm, golden early morning sunlight, casting long, soft shadows and highlighting the rich saturation of the fruits. The atmosphere is cheerful, clean, and full of life, optimized for a low-poly mobile aesthetic while retaining high visual charm and detail.

# Technical Specifications

*   **Triangle Count Target**:
    *   **Scene Total**: Maximum 10,000 triangles (strict adherence required for mobile optimization).
    *   **Breakdown Recommendation**:
        *   Ground & Base Structures (cobblestone, main market square): ~2,000 tris
        *   Market Stalls (frames, roofs, basic counters): ~2,000 tris (instanced)
        *   Fruit Displays (apples, bananas, oranges, grapes - instanced & optimized meshes): ~4,000 tris
        *   Market Signs & Minor Props (baskets, crates, decorative elements): ~2,000 tris
    *   **Optimization Strategy**: Aggressive instancing of fruit models, use of LODs (Level of Detail) if animated or interactive, baking detail into normal maps where appropriate, and prioritizing silhouette over polygon count for distant objects.

*   **Texture Resolutions**:
    *   **Main Environment Atlas (Ground, Stalls, Signs)**: 1024x1024 pixels (PNG or TGA)
    *   **Fruit Atlas (All Fruit Types)**: 512x512 pixels (PNG or TGA)
    *   **Detail Textures (e.g., wood grain, specific fabric patterns)**: 256x256 pixels (if separate, otherwise include in atlas)
    *   **Resolution Strategy**: Utilize texture atlases extensively to minimize draw calls. Maximize UV space efficiency.

*   **Material Workflow**:
    *   **PBR (Physically Based Rendering) - Stylized**: Prioritize a clean, vibrant Albedo/Base Color map.
    *   **Maps Required**:
        *   **Albedo/Base Color**: Primary map, highly saturated, clean color.
        *   **Roughness**: Subtle variations to indicate wood, stone, and the slightly waxy sheen of fruit. Avoid overly reflective surfaces for stylized look.
        *   **Normal Map**: Baked from high-poly sculpts for subtle details (e.g., wood grain, cobblestone crevices, fruit dimples) to enhance visual fidelity without increasing poly count.
        *   **Ambient Occlusion (Baked)**: Pre-baked AO for soft contact shadows and depth, enhancing the "Pixar-like" feel.
    *   **Shader Complexity**: Keep shaders simple; avoid complex lighting calculations or tessellation. Focus on efficient mobile-friendly PBR shaders.

*   **File Format Recommendations**:
    *   **3D Models**: FBX (.fbx) - widely supported, preserves hierarchies, materials, and UVs.
    *   **Textures**: PNG (.png) or TGA (.tga) - support alpha channels if needed, good quality for game assets.

# Detailed Scene Description

*   **Breakdown of the Geometry**:
    *   **Foreground**: The closest market stall will be the hero element, showcasing the most detailed fruit arrangements (apples, bananas) and a clear view of the cobblestone ground. A small, open wooden crate or basket might sit nearby, hinting at market activity.
    *   **Midground**: Two to three additional market stalls are arranged around the hero stall, forming a semi-circle. These stalls display oranges, grapes, and a mix of other fruits, with varying heights and compositions. Simple market signs hang above them, readable but not overly complex. The cobblestone ground extends through this area, perhaps transitioning slightly to worn wooden planks near the stalls.
    *   **Background**: Distant, simplified market stalls or very basic, stylized building facades provide context without drawing focus. These elements will have minimal detail and lower texture resolution, relying on silhouette and color to define them. A few stylized, low-poly trees or bushes might frame the scene.

*   **Color Palette**:
    *   **Primary Fruit Colors**:
        *   Apples: Bright Red (#E53935), Granny Smith Green (#66BB6A)
        *   Bananas: Sunny Yellow (#FFD600), Ripe Yellow (#FFEB3B)
        *   Oranges: Vibrant Orange (#FF9800), Tangerine (#FB8C00)
        *   Grapes: Deep Purple (#673AB7), Leaf Green (#4CAF50)
    *   **Market Stall & Ground**:
        *   Wood Stalls: Light Brown (#A1887F), Weathered Grey-Brown (#8D6E63), Accent Colors (Robin's Egg Blue: #81D4FA, Sunny Yellow: #FFF176, Warm Red: #EF5350)
        *   Cobblestone: Warm Grey (#B0BEC5), Darker Grey (#78909C), Mossy Green Accents (#A5D6A7)
    *   **Overall Mood**: Dominated by warm, inviting tones. High saturation for fruits, softer desaturation for structural elements to make the produce pop.

*   **Lighting Setup details**:
    *   **Key Light (Sun)**: A single, low-angle directional light representing the early morning sun.
        *   **Color**: Warm, golden-yellow (#FFEB3B or #FFC107).
        *   **Angle**: Approximately 30-45 degrees above the horizon, casting noticeable, elongated soft shadows from the stalls and larger fruit piles.
        *   **Intensity**: Bright enough to illuminate the scene clearly without blowing out highlights.
    *   **Fill Light (Sky Dome)**: A soft, cool blue or light purple ambient light to simulate sky bounce.
        *   **Color**: Light Sky Blue (#BBDEFB) or Pale Lavender (#E1BEE7).
        *   **Intensity**: Low, to gently lift shadows and provide subtle color variation without flattening the scene.
    *   **Bounce Light (Indirect)**: Subtle, pre-baked indirect lighting to simulate color bounce from the ground and stall elements onto the underside of fruits and structures, enhancing realism within the stylized context.
    *   **Atmosphere**: A very subtle, warm haze or bloom effect to enhance the "early morning" glow and soften hard edges, contributing to the inviting mood.

# Variant Prompts

1.  **Luma Genie Specific**:
    "Generate a stylized 3D model of a rustic wooden market stall overflowing with highly detailed, vibrant fruit. The stall structure should feature a striped fabric canopy and a weathered wooden counter. Display piles of glossy red apples, yellow bananas, and orange oranges. The individual fruit models should be distinct, low-poly, and optimized for mobile, with baked normal maps for subtle texture."

2.  **Meshy.ai Specific**:
    "Create an optimized low-poly 3D environment asset of a stylized fruit market corner. The scene includes two interconnected wooden market stalls, a section of cobblestone ground, and a simple market sign. Focus on clean geometry, efficient UV mapping for texture atlases, and distinct material zones for wood, stone, and fruit. The fruit (apples, bananas, oranges, grapes) should be instanced and have a clear, vibrant albedo map."

3.  **Concept Art (Midjourney)**:
    "A vibrant, stylized Pixar-like concept art illustration of an early morning fruit market. Focus on a wide shot composition, emphasizing the warm, golden light filtering through a bustling market square. Show multiple rustic wooden stalls bursting with colorful, fresh produce like perfectly stacked red apples, ripe yellow bananas, and luscious purple grapes. The ground is a mix of cobblestones and wooden planks, reflecting the warm glow. Emphasize soft, inviting shadows, rich color saturation, and a cheerful, wholesome atmosphere. Cinematic angle, high detail, volumetric lighting."