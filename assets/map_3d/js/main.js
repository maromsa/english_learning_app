import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

// --- Configuration ---
// index.html lives at …/assets/assets/map_3d/index.html. fetch()/GLTFLoader
// resolve URLs against the document URL (index.html), not this script's path.
// Models live alongside index.html at …/assets/assets/map_3d/models/.
const ASSET_PATH = 'models/';
const MAP_FILE = 'map_island.glb';
const CHARACTER_FILE = 'spark.glb';

// Helper: returns the current iframe viewport size, falling back to
// document dimensions. window.innerWidth can be 0 on iframe first paint.
function _viewportWidth()  { return window.innerWidth  || document.documentElement.clientWidth  || 300; }
function _viewportHeight() { return window.innerHeight || document.documentElement.clientHeight || 500; }

// Fallback positions if map nodes are not found (x, y, z)
const LEVEL_POSITIONS = [
    new THREE.Vector3(0, 0, 0),    // Level 1: Market (Center/Start)
    new THREE.Vector3(5, 1, -4),   // Level 2: Forest
    new THREE.Vector3(-5, 2, -5),  // Level 3: Magic
    new THREE.Vector3(-6, 3, 4),   // Level 4: Mountain
    new THREE.Vector3(6, 0.5, 5),  // Level 5: Ocean/Vehicles
    new THREE.Vector3(0, 5, 0)     // Level 6: Sky/Space
];

// State
let scene, camera, renderer, controls;
let character, mixer, idleAction, walkAction;
let mapModel;
let levels = []; // Array of level data from Flutter
let currentLevelIndex = 0;
let isMoving = false;
let targetPosition = null;
let clickRaycaster = new THREE.Raycaster();
let mouse = new THREE.Vector2();
let levelMarkers = [];

function _notifyParentMapLoaded(status) {
    const loadingEl = document.getElementById('loading');
    if (loadingEl) loadingEl.style.display = 'none';

    if (typeof window._notifyMapLoaded === 'function') {
        window._notifyMapLoaded();
    }

    if (window.parent && window.parent.postMessage) {
        window.parent.postMessage({ type: '3D_MAP_LOADED', status: status }, '*');
    }
}

function _applyMapIslandOptimizations(mapIsland) {
    mapIsland.traverse((child) => {
        if (child.isMesh) {
            child.castShadow = false;
            child.receiveShadow = false;

            if (child.material) {
                child.material.roughness = 1.0;
                child.material.metalness = 0.0;
                child.material.envMapIntensity = 0.0;
            }
        }
    });
}

/** Center the island at the origin and scale to a readable footprint for the scene. */
function _fitMapIslandToScene(mapIsland) {
    const box = new THREE.Box3().setFromObject(mapIsland);
    const size = box.getSize(new THREE.Vector3());
    const center = box.getCenter(new THREE.Vector3());

    mapIsland.position.sub(center);

    const maxDim = Math.max(size.x, size.y, size.z);
    const targetSize = 40;
    if (maxDim > 0) {
        mapIsland.scale.setScalar(targetSize / maxDim);
    }

    mapIsland.updateMatrixWorld(true);
}

// --- Initialization ---
function init() {
    // 1. Scene
    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x87CEEB); // Sky blue
    scene.fog = new THREE.Fog(0x87CEEB, 50, 200);

    // 2. Camera
    // Use _viewportWidth/Height helpers — window.innerWidth can be 0 on
    // the first paint inside an iframe, which causes a broken aspect ratio.
    camera = new THREE.PerspectiveCamera(60, _viewportWidth() / _viewportHeight(), 0.1, 1000);
    camera.position.set(0, 30, 40);
    camera.lookAt(0, 0, 0);

    // 3. Renderer
    renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setSize(_viewportWidth(), _viewportHeight());
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2)); // cap at 2× to avoid OOM
    renderer.shadowMap.enabled = true;
    document.getElementById('canvas-container').appendChild(renderer.domElement);

    // 4. Lights
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
    scene.add(ambientLight);

    const dirLight = new THREE.DirectionalLight(0xffffff, 1);
    dirLight.position.set(10, 20, 10);
    dirLight.castShadow = true;
    dirLight.shadow.mapSize.width = 2048;
    dirLight.shadow.mapSize.height = 2048;
    scene.add(dirLight);

    // 5. Controls
    controls = new OrbitControls(camera, renderer.domElement);
    controls.target.set(0, 0, 0);
    controls.enableDamping = true;
    controls.dampingFactor = 0.05;
    controls.maxPolarAngle = Math.PI / 2 - 0.1; // Don't go below ground
    controls.minDistance = 15;
    controls.maxDistance = 100;
    controls.update();

    // 6. Load Assets
    loadAssets();

    // 7. Event Listeners
    window.addEventListener('resize', onWindowResize);
    window.addEventListener('click', onMouseClick);
    window.addEventListener('touchstart', onTouchStart, { passive: false });

    // 8. Start Loop
    animate();
}

function loadAssets() {
    const loader = new GLTFLoader();

    // Load Map (with performance optimizations for mobile WebGL)
    loader.load(
        ASSET_PATH + MAP_FILE,
        (gltf) => {
            mapModel = gltf.scene;
            _applyMapIslandOptimizations(mapModel);
            _fitMapIslandToScene(mapModel);
            scene.add(mapModel);
            console.log('✅ Map island loaded successfully with optimizations.');

            _notifyParentMapLoaded('success');

            // Try to find named nodes for levels (world space, after fit/scale)
            const worldPos = new THREE.Vector3();
            for (let i = 0; i < LEVEL_POSITIONS.length; i++) {
                const node = mapModel.getObjectByName(`Level${i + 1}`);
                if (node) {
                    node.getWorldPosition(worldPos);
                    LEVEL_POSITIONS[i].copy(worldPos);
                }
            }

            if (character) {
                character.position.copy(LEVEL_POSITIONS[0]);
            }

            setupLevelMarkers();
        },
        (xhr) => {
            if (xhr.total) {
                console.log(`Map Island: ${(xhr.loaded / xhr.total * 100).toFixed(0)}% loaded`);
            }
        },
        (error) => {
            console.error('❌ Error loading map island:', error);
            createPlaceholderMap();
            setupLevelMarkers();
            // Placeholder is shown — treat as "loaded" so the Flutter overlay
            // doesn't hang. The placeholder map still renders correctly.
            _notifyParentMapLoaded('success');
        }
    );

    // Load Character
    loader.load(
        ASSET_PATH + CHARACTER_FILE,
        (gltf) => {
            character = gltf.scene;
            character.scale.set(0.5, 0.5, 0.5); // Adjust scale
            character.position.copy(LEVEL_POSITIONS[0]);

            character.traverse((child) => {
                if (child.isMesh) child.castShadow = true;
            });

            scene.add(character);

            // Animation
            if (gltf.animations.length > 0) {
                mixer = new THREE.AnimationMixer(character);
                const clips = gltf.animations;
                const walkClip = THREE.AnimationClip.findByName(clips, 'Walk') || clips[0];
                const idleClip = THREE.AnimationClip.findByName(clips, 'Idle') || clips[0];

                walkAction = mixer.clipAction(walkClip);
                idleAction = mixer.clipAction(idleClip);

                idleAction.play();
            }
            console.log('✅ Character (Spark) loaded successfully.');
        },
        (xhr) => {
            if (xhr.total) {
                console.log(`Character: ${(xhr.loaded / xhr.total * 100).toFixed(0)}% loaded`);
            }
        },
        (error) => {
            console.error('❌ Error loading character:', error);
            createPlaceholderCharacter();
        }
    );
}

function createPlaceholderMap() {
    // Create a simple ground plane
    const geometry = new THREE.CylinderGeometry(15, 15, 1, 32);
    const material = new THREE.MeshStandardMaterial({ color: 0x228B22 }); // Forest Green
    const ground = new THREE.Mesh(geometry, material);
    ground.position.y = -0.5;
    ground.receiveShadow = true;
    scene.add(ground);

    // Add some "islands"
    LEVEL_POSITIONS.forEach((pos) => {
        const platformGeo = new THREE.CylinderGeometry(2, 2.5, 0.5, 8);
        const platformMat = new THREE.MeshStandardMaterial({ color: 0x8B4513 });
        const platform = new THREE.Mesh(platformGeo, platformMat);
        platform.position.copy(pos);
        platform.position.y -= 0.5; // Sit below the marker
        scene.add(platform);
    });
}

function createPlaceholderCharacter() {
    const geometry = new THREE.CapsuleGeometry(0.5, 1, 4, 8);
    const material = new THREE.MeshStandardMaterial({ color: 0xff0000 });
    character = new THREE.Mesh(geometry, material);
    character.position.copy(LEVEL_POSITIONS[0]);
    character.position.y += 1;
    character.castShadow = true;
    scene.add(character);
}

function setupLevelMarkers() {
    // Remove old markers
    levelMarkers.forEach(m => scene.remove(m));
    levelMarkers = [];

    const geometry = new THREE.SphereGeometry(0.6, 16, 16);

    LEVEL_POSITIONS.forEach((pos, index) => {
        // Different color for locked/unlocked
        const isUnlocked = levels[index] ? levels[index].isUnlocked : (index === 0);
        const isCompleted = levels[index] ? levels[index].stars > 0 : false;

        let color = 0x888888; // Locked (Grey)
        if (isUnlocked) color = 0x4A90E2; // Active (Blue)
        if (isCompleted) color = 0x50C878; // Completed (Green)

        const material = new THREE.MeshStandardMaterial({
            color: color,
            emissive: isUnlocked ? color : 0x000000,
            emissiveIntensity: 0.5,
            roughness: 0.2,
            metalness: 0.5
        });

        const marker = new THREE.Mesh(geometry, material);
        marker.position.copy(pos);
        marker.position.y += 1.0; // Float above ground

        // Add user data for clicking
        marker.userData = { isLevel: true, index: index, isUnlocked: isUnlocked };

        scene.add(marker);
        levelMarkers.push(marker);
    });
}

// --- Interaction ---
function onMouseClick(event) {
    handleInput(event.clientX, event.clientY);
}

function onTouchStart(event) {
    if (event.touches.length > 0) {
        handleInput(event.touches[0].clientX, event.touches[0].clientY);
    }
}

function handleInput(x, y) {
    if (isMoving) return;

    mouse.x = (x / window.innerWidth) * 2 - 1;
    mouse.y = -(y / window.innerHeight) * 2 + 1;

    clickRaycaster.setFromCamera(mouse, camera);
    const intersects = clickRaycaster.intersectObjects(scene.children);

    for (let i = 0; i < intersects.length; i++) {
        const obj = intersects[i].object;
        if (obj.userData && obj.userData.isLevel) {
            const index = obj.userData.index;
            if (obj.userData.isUnlocked) {
                moveToLevel(index);
            } else {
                // Locked feedback
                notifyFlutter('level_locked', { index: index });
            }
            break;
        }
    }
}

function moveToLevel(index) {
    if (index === currentLevelIndex) {
        // Already here, enter level
        notifyFlutter('enter_level', { index: index });
        return;
    }

    targetPosition = LEVEL_POSITIONS[index].clone();

    // Face target
    character.lookAt(targetPosition.x, character.position.y, targetPosition.z);

    isMoving = true;
    currentLevelIndex = index;

    // Animation
    if (walkAction && idleAction) {
        idleAction.fadeOut(0.2);
        walkAction.reset().fadeIn(0.2).play();
    }
}

// --- Animation Loop ---
const clock = new THREE.Clock();

function animate() {
    requestAnimationFrame(animate);

    const delta = clock.getDelta();

    if (mixer) mixer.update(delta);

    if (controls) controls.update();

    // Movement Logic
    if (isMoving && character && targetPosition) {
        const speed = 5.0 * delta;
        const direction = new THREE.Vector3().subVectors(targetPosition, character.position);
        direction.y = 0; // Flatten

        const dist = direction.length();

        if (dist < 0.1) {
            // Arrived
            character.position.x = targetPosition.x;
            character.position.z = targetPosition.z;
            isMoving = false;
            targetPosition = null;

            if (walkAction && idleAction) {
                walkAction.fadeOut(0.2);
                idleAction.reset().fadeIn(0.2).play();
            }
        } else {
            direction.normalize();
            character.position.addScaledVector(direction, speed);
        }
    }

    // Hover effect for markers
    const time = clock.getElapsedTime();
    levelMarkers.forEach((marker, i) => {
        marker.position.y = LEVEL_POSITIONS[i].y + 1.0 + Math.sin(time * 2 + i) * 0.1;
        marker.rotation.y += 0.01;
    });

    renderer.render(scene, camera);
}

function onWindowResize() {
    camera.aspect = _viewportWidth() / _viewportHeight();
    camera.updateProjectionMatrix();
    renderer.setSize(_viewportWidth(), _viewportHeight());
}

// --- Bridge to Flutter ---
function notifyFlutter(type, data) {
    console.log('Notify Flutter:', type, data);
    // Use JavascriptChannel name 'MapChannel'
    if (window.MapChannel) {
        window.MapChannel.postMessage(JSON.stringify({ type: type, data: data }));
    }
}

// Global functions callable from Flutter
window.updateLevels = function(levelsData) {
    console.log('Updating levels:', levelsData);
    levels = levelsData;
    setupLevelMarkers();
};

window.setAvatar = function(avatarType) {
    // TODO: Switch character model if needed
    console.log('Set avatar:', avatarType);
};

// Start
init();
