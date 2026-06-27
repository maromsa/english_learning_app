import * as functions from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2";
import * as logger from "firebase-functions/logger";
import cors from "cors";
import {GoogleGenerativeAI, HarmBlockThreshold, HarmCategory} from "@google/generative-ai";
import {z} from "zod";

const GEMINI_API_VERSION = "v1";
const PRIMARY_MODEL = "gemini-2.5-flash";
const FALLBACK_MODEL = "gemini-2.0-flash";
const GEMINI_MODEL_OVERRIDE = process.env.GEMINI_MODEL_OVERRIDE?.trim();

/**
 * Set ALLOW_UNAUTHENTICATED=true only for local emulator testing.
 * In production every request must carry a valid Firebase ID token.
 */
const ALLOW_UNAUTHENTICATED = process.env.ALLOW_UNAUTHENTICATED === "true";

interface GetModelOptions {
  apiVersion?: string;
  directModelId?: string;
}

setGlobalOptions({
  region: "us-central1",
  maxInstances: 10,
});

const corsHandler = cors({origin: true});

const identifySchema = z.object({
  mode: z.literal("identify"),
  prompt: z.string().min(1),
  mimeType: z.string().default("image/jpeg"),
  imageBase64: z.string().min(1),
});

const validateSchema = z.object({
  word: z.string().min(1),
  mimeType: z.string().default("image/jpeg"),
  imageBase64: z.string().min(1),
});

const storySchema = z.object({
  mode: z.literal("story"),
  prompt: z.string().min(1),
  system_instruction: z.string().optional(),
  systemInstruction: z.string().optional(),
}).transform((data) => mapSystemInstruction({
  mode: data.mode,
  prompt: data.prompt,
}, data));

const textSchema = z.object({
  mode: z.literal("text"),
  prompt: z.string().min(1),
  system_instruction: z.string().optional(),
  systemInstruction: z.string().optional(),
}).transform((data) => mapSystemInstruction({
  mode: data.mode,
  prompt: data.prompt,
}, data));

const ttsSchema = z.object({
  mode: z.literal("tts"),
  text: z.string().min(1).max(2000).optional(),
  ssml: z.string().min(1).max(4000).optional(),
  languageCode: z.string().min(2).max(20).default("he-IL"),
  voiceName: z.string().min(1).max(60).optional(),
  speakingRate: z.number().min(0.25).max(4).default(1),
  pitch: z.number().min(-20).max(20).default(0),
  volumeGainDb: z.number().min(-96).max(16).default(0),
}).refine(
    (data) => data.text !== undefined || data.ssml !== undefined,
    {message: "Either text or ssml is required"},
);

const pixabaySchema = z.object({
  mode: z.literal("pixabay"),
  query: z.string().min(1).max(200),
  perPage: z.number().int().min(1).max(20).default(8),
});

// ElevenLabs TTS — returns raw MP3 bytes as base64.
const elevenLabsSchema = z.object({
  mode: z.literal("elevenlabs"),
  text: z.string().min(1).max(2000),
  // Defaults to a child-friendly English voice; callers can override.
  voiceId: z.string().min(1).max(100).default("EXAVITQu4vr4xnSDxMaL"),
  modelId: z.string().min(1).max(100).default("eleven_turbo_v2_5"),
  stability: z.number().min(0).max(1).default(0.5),
  similarityBoost: z.number().min(0).max(1).default(0.75),
  style: z.number().min(0).max(1).default(0),
  useSpeakerBoost: z.boolean().default(true),
});

const sceneDescriptionSchema = z.object({
  mode: z.literal("scene_description"),
  prompt: z.string().min(1),
  mimeType: z.string().default("image/jpeg"),
  imageBase64: z.string().min(1),
  system_instruction: z.string().optional(),
  systemInstruction: z.string().optional(),
}).transform((data) => mapSystemInstruction({
  mode: data.mode,
  prompt: data.prompt,
  mimeType: data.mimeType,
  imageBase64: data.imageBase64,
}, data));

function mapSystemInstruction<T extends Record<string, unknown>>(
    base: T,
    data: {system_instruction?: string; systemInstruction?: string},
): T & {systemInstruction?: string} {
  const systemInstruction = data.system_instruction ?? data.systemInstruction;
  if (systemInstruction === undefined) {
    return base;
  }
  return {...base, systemInstruction};
}

type IdentifyPayload = z.infer<typeof identifySchema>;
type TtsPayload = z.infer<typeof ttsSchema>;
type ValidatePayload = z.infer<typeof validateSchema>;
type StoryPayload = z.infer<typeof storySchema>;
type TextPayload = z.infer<typeof textSchema>;
type SceneDescriptionPayload = z.infer<typeof sceneDescriptionSchema>;
type PixabayPayload = z.infer<typeof pixabaySchema>;
type ElevenLabsPayload = z.infer<typeof elevenLabsSchema>;

/**
 * Firebase/Express may deliver JSON as a string, Buffer, or (rarely) a
 * single-element array. Normalize to a plain object before Zod validation.
 */
function parseRequestBody(body: unknown): Record<string, unknown> {
  let value: unknown = body;

  if (typeof value === "string" && value.trim().length > 0) {
    value = JSON.parse(value);
  } else if (Buffer.isBuffer(value)) {
    value = JSON.parse(value.toString("utf8"));
  }

  if (Array.isArray(value)) {
    if (value.length === 1 && typeof value[0] === "object" && value[0] !== null && !Array.isArray(value[0])) {
      value = value[0];
    } else {
      throw new z.ZodError([{
        code: "custom",
        path: [],
        message: "Request body must be a JSON object, not an array",
      }]);
    }
  }

  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new z.ZodError([{
      code: "custom",
      path: [],
      message: "Request body must be a JSON object",
    }]);
  }

  return value as Record<string, unknown>;
}

const safetySettings = [
  {category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE},
  {category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE},
  {category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE},
  {category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE},
];

/**
 * Lightweight per-user rate limiter (sliding window, in-memory).
 *
 * Each function instance keeps its own counters, so the real global limit is
 * `RATE_LIMIT_MAX_REQUESTS × active instances` — good enough as a cost guard
 * against a runaway client or a leaked token, without adding a datastore
 * dependency to every AI call.
 */
const RATE_LIMIT_WINDOW_MS = 60_000;
const RATE_LIMIT_MAX_REQUESTS = Number(process.env.RATE_LIMIT_MAX_REQUESTS ?? 30);
const rateLimitBuckets = new Map<string, number[]>();

function isRateLimited(uid: string, nowMs: number = Date.now()): boolean {
  const windowStart = nowMs - RATE_LIMIT_WINDOW_MS;
  const recent = (rateLimitBuckets.get(uid) ?? []).filter((t) => t > windowStart);

  if (recent.length >= RATE_LIMIT_MAX_REQUESTS) {
    rateLimitBuckets.set(uid, recent);
    return true;
  }

  recent.push(nowMs);
  rateLimitBuckets.set(uid, recent);

  // Bound total memory: drop stale buckets once the map grows large.
  if (rateLimitBuckets.size > 10_000) {
    for (const [key, timestamps] of rateLimitBuckets) {
      if (timestamps.every((t) => t <= windowStart)) {
        rateLimitBuckets.delete(key);
      }
    }
  }

  return false;
}

/**
 * Verifies the Firebase ID token in the Authorization header.
 * Returns the authenticated uid, or null when the token is missing/invalid.
 */
async function verifyAuth(authorizationHeader: string | undefined): Promise<string | null> {
  const match = authorizationHeader?.match(/^Bearer (.+)$/i);
  if (!match) {
    return null;
  }
  try {
    // Lazy-load firebase-admin so unit tests don't need a configured app.
    const {getApps, initializeApp} = await import("firebase-admin/app");
    const {getAuth} = await import("firebase-admin/auth");
    if (getApps().length === 0) {
      initializeApp();
    }
    const decoded = await getAuth().verifyIdToken(match[1]);
    return decoded.uid;
  } catch (error) {
    logger.warn("ID token verification failed", {
      errorMessage: error instanceof Error ? error.message : String(error),
    });
    return null;
  }
}

function getModel(
    apiKey: string,
    systemInstruction?: string,
    options: GetModelOptions = {},
) {
  const client = new GoogleGenerativeAI(apiKey);
  const resolvedModelId = options.directModelId ?? PRIMARY_MODEL;

  // NOTE: the API requires snake_case "system_instruction" (camelCase is rejected).
  const modelConfig: Record<string, unknown> = {
    model: resolvedModelId,
    safetySettings,
  };
  if (systemInstruction && systemInstruction.trim().length > 0) {
    modelConfig.system_instruction = systemInstruction;
  }

  const requestOptions = {
    apiVersion: (options.apiVersion ?? GEMINI_API_VERSION) as "v1",
  };

  return client.getGenerativeModel(modelConfig as never, requestOptions);
}

function isModelNotFoundError(error: unknown): error is Error {
  if (!(error instanceof Error)) {
    return false;
  }
  const lower = (error.message ?? "").toLowerCase();
  return lower.includes("404 not found") ||
    lower.includes("is not found") ||
    (lower.includes("model") && lower.includes("not found")) ||
    lower.includes("not supported for generatecontent");
}

function buildModelOrder(): string[] {
  const order: string[] = [];
  for (const candidate of [GEMINI_MODEL_OVERRIDE, PRIMARY_MODEL, FALLBACK_MODEL]) {
    if (candidate && !order.includes(candidate)) {
      order.push(candidate);
    }
  }
  return order;
}

async function runWithModelFallback<T>({
  apiKey,
  systemInstruction,
  mode,
  action,
}: {
  apiKey: string;
  systemInstruction?: string;
  mode: string;
  action: (model: ReturnType<typeof getModel>) => Promise<T>;
}): Promise<T> {
  const modelOrder = buildModelOrder();
  let lastModelError: unknown;

  for (const directModelId of modelOrder) {
    const model = getModel(apiKey, systemInstruction, {directModelId});
    try {
      return await action(model);
    } catch (error) {
      if (!isModelNotFoundError(error)) {
        throw error;
      }
      lastModelError = error;
      logger.warn("Gemini model not found - trying fallback", {mode, model: directModelId});
    }
  }

  const lastMessage = lastModelError instanceof Error ? `: ${lastModelError.message}` : ".";
  throw new Error(
      `Gemini model not available after trying ${modelOrder.length} model(s)${lastMessage}`,
  );
}

async function generateMultimodalContent(
    payload: {prompt: string; mimeType: string; imageBase64: string},
    apiKey: string,
    mode: string,
    systemInstruction?: string,
) {
  const result = await runWithModelFallback({
    apiKey,
    systemInstruction,
    mode,
    action: async (model) => {
      return model.generateContent({
        contents: [{
          role: "user",
          parts: [
            {text: payload.prompt},
            {
              inlineData: {
                data: payload.imageBase64,
                mimeType: payload.mimeType,
              },
            },
          ],
        }],
      });
    },
  });
  const text = result.response.text()?.trim() ?? "";
  return {text};
}

async function handleIdentify(payload: IdentifyPayload, apiKey: string) {
  return generateMultimodalContent(payload, apiKey, "identify");
}

async function handleSceneDescription(payload: SceneDescriptionPayload, apiKey: string) {
  return generateMultimodalContent(
      payload,
      apiKey,
      "scene_description",
      payload.systemInstruction,
  );
}

async function handleValidate(payload: ValidatePayload, apiKey: string) {
  const prompt = `You are helping a child learn English words.
Does this picture clearly show the object "${payload.word}" as the main focus?
Answer strictly with "yes" or "no" and provide a confidence score between 0 and 1. Return JSON: {"approved": boolean, "confidence": number}.`;

  const result = await runWithModelFallback({
    apiKey,
    mode: "validate",
    action: async (model) => {
      return model.generateContent({
        contents: [{
          role: "user",
          parts: [
            {text: prompt},
            {
              inlineData: {
                data: payload.imageBase64,
                mimeType: payload.mimeType,
              },
            },
          ],
        }],
      });
    },
  });

  const text = result.response.text()?.trim() ?? "";
  let approved = false;
  let confidence: number | null = null;

  try {
    const parsed = JSON.parse(text);
    if (typeof parsed === "object" && parsed !== null) {
      if (typeof parsed.approved === "boolean") {
        approved = parsed.approved;
      }
      if (typeof parsed.confidence === "number") {
        confidence = parsed.confidence;
      }
    }
  } catch {
    logger.warn("Failed parsing validation JSON", {textLength: text.length});
  }

  if (confidence === null) {
    const normalized = text.toLowerCase();
    if (normalized.includes("yes")) {
      approved = true;
      confidence = 0.75;
    } else if (normalized.includes("no")) {
      approved = false;
      confidence = 0.25;
    }
  }

  return {approved, confidence};
}

/**
 * Synthesizes speech via Google Cloud Text-to-Speech using a server-side
 * API key, so the key never ships inside the client app.
 * Returns base64 MP3 in `audioContent`.
 */
async function handleTts(payload: TtsPayload, ttsApiKey: string) {
  const response = await fetch(
      `https://texttospeech.googleapis.com/v1/text:synthesize?key=${ttsApiKey}`,
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({
          input: payload.ssml !== undefined ?
            {ssml: payload.ssml} :
            {text: payload.text},
          voice: {
            languageCode: payload.languageCode,
            ...(payload.voiceName ? {name: payload.voiceName} : {}),
            ssmlGender: "FEMALE",
          },
          audioConfig: {
            audioEncoding: "MP3",
            speakingRate: payload.speakingRate,
            pitch: payload.pitch,
            volumeGainDb: payload.volumeGainDb,
            effectsProfileId: ["headphone-class-device"],
            sampleRateHertz: 24000,
          },
        }),
      },
  );

  if (!response.ok) {
    logger.error("TTS synthesis failed", {status: response.status});
    throw new Error(`TTS synthesis failed with status ${response.status}`);
  }

  const data = await response.json() as {audioContent?: string};
  if (!data.audioContent) {
    throw new Error("TTS synthesis returned no audio");
  }
  return {audioContent: data.audioContent};
}

/**
 * Synthesizes speech via ElevenLabs API.
 * Returns base64 MP3 in `audioContent` — same shape as the Google TTS handler
 * so the client can use both interchangeably.
 */
async function handleElevenLabs(payload: ElevenLabsPayload, apiKey: string) {
  const url = `https://api.elevenlabs.io/v1/text-to-speech/${payload.voiceId}`;
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "xi-api-key": apiKey,
      "Content-Type": "application/json",
      "Accept": "audio/mpeg",
    },
    body: JSON.stringify({
      text: payload.text,
      model_id: payload.modelId,
      voice_settings: {
        stability: payload.stability,
        similarity_boost: payload.similarityBoost,
        style: payload.style,
        use_speaker_boost: payload.useSpeakerBoost,
      },
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text().catch(() => "");
    logger.error("ElevenLabs TTS failed", {status: response.status, errorBody: errorBody.slice(0, 200)});
    throw new Error(`ElevenLabs TTS failed with status ${response.status}`);
  }

  // Response is raw MP3 bytes — convert to base64 for JSON transport.
  const arrayBuffer = await response.arrayBuffer();
  const base64 = Buffer.from(arrayBuffer).toString("base64");
  return {audioContent: base64};
}

async function handleText(payload: TextPayload | StoryPayload, apiKey: string) {
  const result = await runWithModelFallback({
    apiKey,
    systemInstruction: payload.systemInstruction,
    mode: payload.mode,
    action: async (model) => {
      return model.generateContent({
        contents: [{
          role: "user",
          parts: [
            {text: payload.prompt},
          ],
        }],
      });
    },
  });

  let text = result.response.text()?.trim() ?? "";

  // Strip markdown code fences if the model wraps its JSON in them.
  const markdownFencePattern = /^```(?:json|JSON)?\s*\n?/i;
  const closingFencePattern = /\n?```\s*$/i;
  if (markdownFencePattern.test(text) || closingFencePattern.test(text)) {
    text = text.replace(markdownFencePattern, "").replace(closingFencePattern, "").trim();
  }

  return {text};
}

/**
 * Proxies Pixabay image search so the API key never ships in the client app.
 * Returns the raw Pixabay hits array.
 */
async function handlePixabay(payload: PixabayPayload, pixabayApiKey: string) {
  const url = new URL("https://pixabay.com/api/");
  url.searchParams.set("key", pixabayApiKey);
  url.searchParams.set("q", payload.query);
  url.searchParams.set("image_type", "photo");
  url.searchParams.set("orientation", "horizontal");
  url.searchParams.set("per_page", String(payload.perPage));
  url.searchParams.set("safesearch", "true");

  const response = await fetch(url.toString());
  if (!response.ok) {
    logger.error("Pixabay search failed", {status: response.status});
    throw new Error(`Pixabay search failed with status ${response.status}`);
  }

  const data = await response.json() as {hits?: unknown[]};
  return {hits: data.hits ?? []};
}

// Export for testing
export {handleText, getModel, parseRequestBody, handleSceneDescription, handleTts, handlePixabay, handleElevenLabs, verifyAuth, isRateLimited};

export const geminiProxy = functions.onRequest(
    {cors: true, secrets: ["GEMINI_API_KEY", "GOOGLE_TTS_API_KEY", "PIXABAY_API_KEY", "ELEVENLABS_API_KEY"]},
    (req, res) => {
      corsHandler(req, res, async () => {
        let requestMode: unknown;
        try {
          if (req.method !== "POST") {
            res.set("Allow", "POST");
            res.status(405).json({error: "Method Not Allowed"});
            return;
          }

          let uid: string | null = null;
          if (!ALLOW_UNAUTHENTICATED) {
            uid = await verifyAuth(req.headers.authorization);
            if (uid === null) {
              res.status(401).json({error: "Unauthorized: valid Firebase ID token required"});
              return;
            }
            if (isRateLimited(uid)) {
              logger.warn("Rate limit exceeded", {uid});
              res.status(429).json({error: "Too many requests, slow down"});
              return;
            }
          }

          const apiKey = process.env.GEMINI_API_KEY;
          if (!apiKey) {
            res.status(500).json({error: "GEMINI_API_KEY is not configured"});
            return;
          }

          const body = parseRequestBody(req.body);
          requestMode = body.mode;

          // Privacy: never log request contents (prompts, images, child data).
          logger.info("geminiProxy request", {mode: requestMode ?? "validate", uid});

          if (body.mode === "tts") {
            const ttsApiKey = process.env.GOOGLE_TTS_API_KEY;
            if (!ttsApiKey) {
              res.status(501).json({error: "TTS is not configured on the server"});
              return;
            }
            const payload = ttsSchema.parse(body);
            const response = await handleTts(payload, ttsApiKey);
            res.json(response);
            return;
          }

          if (body.mode === "pixabay") {
            const pixabayApiKey = process.env.PIXABAY_API_KEY;
            if (!pixabayApiKey) {
              res.status(501).json({error: "Pixabay is not configured on the server"});
              return;
            }
            const payload = pixabaySchema.parse(body);
            const response = await handlePixabay(payload, pixabayApiKey);
            res.json(response);
            return;
          }

          if (body.mode === "identify") {
            const payload = identifySchema.parse(body);
            const response = await handleIdentify(payload, apiKey);
            res.json(response);
            return;
          }

          if (body.mode === "scene_description") {
            const payload = sceneDescriptionSchema.parse(body);
            const response = await handleSceneDescription(payload, apiKey);
            res.json(response);
            return;
          }

          if (body.mode === "story" || body.mode === "text") {
            const payload = (body.mode === "story" ? storySchema : textSchema).parse(body);
            const response = await handleText(payload, apiKey);
            res.json(response);
            return;
          }

          if (body.mode === "elevenlabs") {
            const elevenLabsApiKey = process.env.ELEVENLABS_API_KEY;
            if (!elevenLabsApiKey) {
              res.status(501).json({error: "ElevenLabs TTS is not configured on the server"});
              return;
            }
            const payload = elevenLabsSchema.parse(body);
            const response = await handleElevenLabs(payload, elevenLabsApiKey);
            res.json(response);
            return;
          }

          // Default to validation payload for compatibility with existing client.
          const payload = validateSchema.parse(body);
          const response = await handleValidate(payload, apiKey);
          res.json(response);
        } catch (error) {
          if (error instanceof z.ZodError) {
            logger.warn("geminiProxy invalid payload", {mode: requestMode});
            res.status(400).json({error: "Invalid payload", details: error.errors});
          } else if (error instanceof Error) {
            logger.error("geminiProxy failed", {
              mode: requestMode,
              errorMessage: error.message,
            });
            // Return a generic message — never echo internal error details to clients.
            res.status(500).json({error: "Internal server error"});
          } else {
            logger.error("geminiProxy failed with unknown error", {mode: requestMode});
            res.status(500).json({error: "Internal server error"});
          }
        }
      });
    },
);
