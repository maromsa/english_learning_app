// --- הגדרות נתיבים ---
// הנתיב לתיקיית המודלים (יחסי לקובץ ה-index.html)
const ASSET_PATH = 'models/';
// שם קובץ האי (המודל הכבד)
const MAP_FILE = 'map_island.glb'; 
// שם קובץ הדמות
const CHARACTER_FILE = 'spark.glb';

/**
 * פונקציה לטעינת המודלים אל תוך הסצנה
 * @param {THREE.Scene} scene - הסצנה של המשחק
 * @param {GLTFLoader} loader - מנגנון הטעינה של Three.js
 */
function load3DAssets(scene, loader) {
    
    // 1. טעינת דמות השחקן (Spark)
    loader.load(
        `${ASSET_PATH}${CHARACTER_FILE}`,
        function (gltf) {
            const character = gltf.scene;
            scene.add(character);
            console.log("✅ Character (Spark) loaded successfully.");
        },
        function (xhr) {
            console.log(`Character: ${(xhr.loaded / xhr.total * 100).toFixed(0)}% loaded`);
        },
        function (error) {
            console.error("❌ Error loading character:", error);
        }
    );

    // 2. טעינת מודל האי (עם אופטימיזציה למניעת קריסות)
    loader.load(
        `${ASSET_PATH}${MAP_FILE}`,
        function (gltf) {
            const mapIsland = gltf.scene;

            // --- תהליך האופטימיזציה (פישוט המודל) ---
            // עוברים על כל החלקים של המודל כדי להקל על הדפדפן
            mapIsland.traverse(function (child) {
                if (child.isMesh) {
                    // ביטול צללים כבדים
                    child.castShadow = false; 
                    child.receiveShadow = false;
                    
                    // הפיכת החומרים (Materials) לפשוטים יותר כדי לחסוך זיכרון
                    if (child.material) {
                        child.material.roughness = 1.0; // חומר לא מבריק
                        child.material.metalness = 0.0; // חומר לא מתכתי
                        child.material.envMapIntensity = 0.0; // ביטול השתקפויות סביבה
                    }
                }
            });

            scene.add(mapIsland);
            console.log("✅ Map island loaded successfully with optimizations.");
            
            // שליחת הודעה לפלאטר שהמפה נטענה
            if (window.parent && window.parent.postMessage) {
                window.parent.postMessage({ type: "3D_MAP_LOADED", status: "success" }, "*");
            }
        },
        function (xhr) {
            console.log(`Map Island: ${(xhr.loaded / xhr.total * 100).toFixed(0)}% loaded`);
        },
        function (error) {
            console.error("❌ Error loading map island:", error);
            if (window.parent && window.parent.postMessage) {
                window.parent.postMessage({ type: "3D_MAP_LOADED", status: "error" }, "*");
            }
        }
    );
}

// ייצוא הפונקציה כדי ששאר הקבצים יוכלו להשתמש בה
window.load3DAssets = load3DAssets;