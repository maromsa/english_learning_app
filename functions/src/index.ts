import * as functions from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2";
import * as logger from "firebase-functions/logger";
import cors from "cors";
import {GoogleGenerativeAI, HarmBlockThreshold, HarmCategory} from "@google/generative-ai";
import {z} from "zod";

const GEMINI_API_VERSION = "v1";
const DEFAULT_MODEL_MAP: Record<string, string> = {
  "gemini-1.5": "gemini-2.0-flash",
};
const GEMINI_MODEL_OVERRIDE = process.env.GEMINI_MODEL_OVERRIDE?.trim();

interface GetModelOptions {
  apiVersion?: string;
  directModelId?: string;
}

interface ModelAttempt {
  apiVersion: string;
  directModelId?: string;
  label: string;
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
}).transform((data) => ({
  ...data,
  ...(data.system_instruction !== undefined && {systemInstruction: data.system_instruction}), // Map to camelCase for internal use (optional)
}));

const textSchema = z.object({
  mode: z.literal("text"),
  prompt: z.string().min(1),
  system_instruction: z.string().optional(),
}).transform((data) => ({
  ...data,
  ...(data.system_instruction !== undefined && {systemInstruction: data.system_instruction}), // Map to camelCase for internal use (optional)
}));

type IdentifyPayload = z.infer<typeof identifySchema>;
type ValidatePayload = z.infer<typeof validateSchema>;
type StoryPayload = z.infer<typeof storySchema>;
type TextPayload = z.infer<typeof textSchema>;

const safetySettings = [
  {category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE},
  {category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE},
  {category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE},
  {category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE},
];

function getModel(
    modelId: string,
    apiKey: string,
    systemInstruction?: string,
    options: GetModelOptions = {},
) {
  logger.info("getModel called", {
    modelId,
    hasSystemInstruction: systemInstruction !== undefined,
    systemInstructionType: typeof systemInstruction,
    systemInstructionLength: systemInstruction?.length,
    systemInstructionValue: systemInstruction,
    directModelOverride: options.directModelId,
    requestedApiVersion: options.apiVersion ?? GEMINI_API_VERSION,
  });

  // Create client - it will use the configured API version via request options
  logger.info("Creating GoogleGenerativeAI client", {
    apiKeyPresent: !!apiKey,
    apiKeyLength: apiKey?.length,
  });
  
  const client = new GoogleGenerativeAI(apiKey);
  logger.info("GoogleGenerativeAI client created successfully");
  
  // Build model config with ONLY snake_case system_instruction (never camelCase)
  // Explicitly construct the object to avoid any camelCase properties
  // Use gemini-2.0-flash - this is a stable model version that works with v1 API
  const modelConfig: any = {
    model: resolvedModelId,
    safetySettings,
  };
  
  // Only add system_instruction if provided and non-empty
  // CRITICAL: Use snake_case only - API rejects camelCase "systemInstruction"
  if (systemInstruction && systemInstruction.trim().length > 0) {
    modelConfig.system_instruction = systemInstruction;
    logger.info("Added system_instruction to modelConfig", {
      systemInstructionLength: systemInstruction.length,
      modelConfigKeys: Object.keys(modelConfig),
    });
  } else {
    logger.info("No systemInstruction provided or empty", {
      systemInstruction,
      trimmedLength: systemInstruction?.trim()?.length,
    });
  }
  
  // Verify no camelCase systemInstruction exists (safety check)
  if (modelConfig.systemInstruction !== undefined) {
    logger.error("ERROR: Found camelCase systemInstruction in modelConfig - removing it!", {
      modelConfigKeys: Object.keys(modelConfig),
    });
    delete modelConfig.systemInstruction;
  }
  
  // Log the model config to verify the payload before API call
  const apiVersion = options.apiVersion ?? GEMINI_API_VERSION;
  logger.info("Model config before getGenerativeModel", {
    modelConfig: JSON.stringify(modelConfig),
    modelConfigKeys: Object.keys(modelConfig),
    hasSystemInstruction: modelConfig.system_instruction !== undefined,
    hasSystemInstructionCamelCase: modelConfig.systemInstruction !== undefined,
    finalModelId: modelConfig.model,
    apiVersion,
  });
  
  // Use getGenerativeModel with explicit v1 API version
  // Using gemini-2.0-flash which is compatible with v1 API
  const requestOptions = {
    apiVersion: GEMINI_API_VERSION as "v1",
  };

  logger.info("Calling getGenerativeModel", {
    modelId,
    finalModelId: modelConfig.model,
    apiVersion: requestOptions.apiVersion,
    directModelOverride: options.directModelId,
  });
  const model = client.getGenerativeModel(modelConfig, requestOptions);
  logger.info("Model created successfully", {
    modelId,
    finalModelId: modelConfig.model,
    baseUrl: "https://generativelanguage.googleapis.com",
    apiVersion: requestOptions.apiVersion,
    directModelOverride: options.directModelId,
  });
  return model;
}

function normalizeModelId(modelId?: string | null): string | undefined {
  if (!modelId) {
    return undefined;
  }
  return modelId.startsWith("models/") ? modelId.slice("models/".length) : modelId;
}

function stripLatestSuffix(modelId?: string | null): string | undefined {
  const normalized = normalizeModelId(modelId);
  if (!normalized) {
    return undefined;
  }
  return normalized.replace(/-latest$/i, "");
}

function uniqueStrings(values: Array<string | undefined>): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const value of values) {
    if (!value) {
      continue;
    }
    if (seen.has(value)) {
      continue;
    }
    seen.add(value);
    result.push(value);
  }
  return result;
}

function uniqueModelOverrides(values: Array<string | undefined>): (string | undefined)[] {
  const seen = new Set<string>();
  const result: (string | undefined)[] = [];
  let defaultAdded = false;

  for (const value of values) {
    if (!value) {
      if (!defaultAdded) {
        result.push(undefined);
        defaultAdded = true;
      }
      continue;
    }

    if (seen.has(value)) {
      continue;
    }
    seen.add(value);
    result.push(value);
  }

  return result;
}

function buildModelAttempts(): ModelAttempt[] {
  const versionOrder = uniqueStrings([
    GEMINI_API_VERSION,
    "v1",
    "v1beta",
  ]);

  const primaryModel = DEFAULT_MODEL_MAP["gemini-1.5"] ?? "gemini-1.5";
  const normalizedPrimary = normalizeModelId(primaryModel);
  const overrideNormalized = normalizeModelId(GEMINI_MODEL_OVERRIDE);

  const modelOrder = uniqueModelOverrides([
    GEMINI_MODEL_OVERRIDE,
    overrideNormalized,
    undefined,
    primaryModel,
    normalizedPrimary,
    stripLatestSuffix(primaryModel),
    stripLatestSuffix(normalizedPrimary),
    "gemini-1.5-flash-latest",
    "gemini-1.5-flash",
    "gemini-1.5",
  ]);

  const attempts: ModelAttempt[] = [];
  const seen = new Set<string>();

  versionOrder.forEach((apiVersion) => {
    for (const directModelId of modelOrder) {
      const key = `${apiVersion}|${directModelId ?? "DEFAULT"}`;
      if (seen.has(key)) {
        continue;
      }
      seen.add(key);
      attempts.push({
        apiVersion,
        directModelId,
        label: `apiVersion=${apiVersion}${directModelId ? `, model=${directModelId}` : ", model=DEFAULT"}`,
      });
    }
  });

  return attempts;
}

function isModelNotFoundError(error: unknown): error is Error {
  if (!(error instanceof Error)) {
    return false;
  }
  const message = error.message ?? "";
  const lower = message.toLowerCase();
  return lower.includes("404 not found") ||
    lower.includes("is not found") ||
    (lower.includes("model") && lower.includes("not found")) ||
    lower.includes("not supported for generatecontent");
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
  const attempts = buildModelAttempts();
  let lastModelError: unknown;

  for (let index = 0; index < attempts.length; index++) {
    const attempt = attempts[index];
    logger.info("Gemini model attempt starting", {
      mode,
      attemptIndex: index + 1,
      attemptTotal: attempts.length,
      attemptLabel: attempt.label,
    });

    const model = getModel("gemini-1.5", apiKey, systemInstruction, {
      apiVersion: attempt.apiVersion,
      directModelId: attempt.directModelId,
    });

    try {
      const result = await action(model);
      logger.info("Gemini model attempt succeeded", {
        mode,
        attemptIndex: index + 1,
        attemptTotal: attempts.length,
        attemptLabel: attempt.label,
      });
      return result;
    } catch (error) {
      if (!isModelNotFoundError(error)) {
        throw error;
      }
      lastModelError = error;
      logger.warn("Gemini model attempt failed - trying fallback", {
        mode,
        attemptIndex: index + 1,
        attemptTotal: attempts.length,
        attemptLabel: attempt.label,
        errorMessage: error.message,
      });
    }
  }

  logger.error("All Gemini model attempts failed", {
    mode,
    attempts: attempts.map((attempt) => attempt.label),
    modelOverride: GEMINI_MODEL_OVERRIDE,
    lastErrorMessage: lastModelError instanceof Error ? lastModelError.message : lastModelError,
  });

  if (lastModelError instanceof Error) {
    throw new Error(
        `Gemini model not available after trying ${attempts.length} attempt(s): ${lastModelError.message}`,
    );
  }

  throw new Error(`Gemini model not available after trying ${attempts.length} attempt(s).`);
}

async function handleIdentify(payload: IdentifyPayload, apiKey: string) {
  logger.info("🔍 handleIdentify called");
  const result = await runWithModelFallback({
    apiKey,
    mode: "identify",
    action: async (model) => {
      logger.info("📤 Calling generateContent for identify");
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
  logger.info("✅ generateContent completed for identify");
  const text = result.response.text()?.trim() ?? "";
  return {text};
}

async function handleValidate(payload: ValidatePayload, apiKey: string) {
  logger.info("🔍 handleValidate called");
  const prompt = `You are helping a child learn English words.
Does this picture clearly show the object "${payload.word}" as the main focus?
Answer strictly with "yes" or "no" and provide a confidence score between 0 and 1. Return JSON: {"approved": boolean, "confidence": number}.`;

  const result = await runWithModelFallback({
    apiKey,
    mode: "validate",
    action: async (model) => {
      logger.info("📤 Calling generateContent for validate");
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
  logger.info("✅ generateContent completed for validate");

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
  } catch (error) {
    logger.warn("Failed parsing validation JSON", {text, error});
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

async function handleText(payload: TextPayload | StoryPayload, apiKey: string) {
  // Pass systemInstruction to getModel so it's set at the model level
  // We use snake_case "system_instruction" directly in getModel to match the API spec
  logger.info("handleText called", {
    systemInstruction: payload.systemInstruction,
    systemInstructionType: typeof payload.systemInstruction,
    systemInstructionLength: payload.systemInstruction?.length,
  });
  
  const generateContentPayload = {
    contents: [{
      role: "user",
      parts: [
        {text: payload.prompt},
      ],
    }],
  };
  
  const result = await runWithModelFallback({
    apiKey,
    systemInstruction: payload.systemInstruction,
    mode: payload.mode,
    action: async (model) => {
      logger.info("📤 Calling generateContent for text/story", {
        payload: JSON.stringify(generateContentPayload),
        payloadKeys: Object.keys(generateContentPayload),
      });
      return model.generateContent(generateContentPayload);
    },
  });
  logger.info("✅ generateContent completed for text/story");
  let text = result.response.text()?.trim() ?? "";
  
  // Strip markdown code fences if present (handles various formats)
  // Examples: ```json\n...\n```, ```\n...\n```, ```json...```, etc.
  // This ensures clean JSON output even if the model wraps it in markdown
  const markdownFencePattern = /^```(?:json|JSON)?\s*\n?/i;
  const closingFencePattern = /\n?```\s*$/i;
  
  if (markdownFencePattern.test(text) || closingFencePattern.test(text)) {
    const originalText = text;
    text = text.replace(markdownFencePattern, '').replace(closingFencePattern, '').trim();
    logger.info("📝 Stripped markdown fences", {
      hadMarkdown: true,
      originalLength: originalText.length,
      cleanedLength: text.length,
    });
  }
  
  logger.info("📝 Final response text", {
    length: text.length,
    startsWithJson: text.startsWith('{'),
    startsWithBracket: text.startsWith('['),
  });
  
  return {text};
}

// Export for testing
export {handleText, getModel};

// Note: Fetch override is now set up at module level (see top of file)
// This ensures it's active before any SDK calls are made

export const geminiProxy = functions.onRequest(
    {cors: true, secrets: ["GEMINI_API_KEY"]},
    (req, res) => {
      corsHandler(req, res, async () => {
        // Fetch override is already active at module level
        try {
          if (req.method !== "POST") {
            res.set("Allow", "POST");
            res.status(405).json({error: "Method Not Allowed"});
            return;
          }

          const apiKey = process.env.GEMINI_API_KEY;
          if (!apiKey) {
            res.status(500).json({error: "GEMINI_API_KEY is not configured"});
            return;
          }

          logger.info("📥 geminiProxy received request", {
            method: req.method,
            body: JSON.stringify(req.body),
            bodyKeys: Object.keys(req.body || {}),
            hasSystemInstruction: req.body?.system_instruction !== undefined || req.body?.systemInstruction !== undefined,
            systemInstructionType: typeof (req.body?.system_instruction ?? req.body?.systemInstruction),
          });

          if (req.body?.mode === "identify") {
            const payload = identifySchema.parse(req.body);
            const response = await handleIdentify(payload, apiKey);
            res.json(response);
            return;
          }

          if (req.body?.mode === "story" || req.body?.mode === "text") {
            const payload = (req.body.mode === "story" ? storySchema : textSchema).parse(req.body);
            logger.info("📝 Parsed payload for text/story mode", {
              mode: payload.mode,
              promptLength: payload.prompt.length,
              hasSystemInstruction: payload.systemInstruction !== undefined,
              systemInstructionLength: payload.systemInstruction?.length,
              systemInstructionPreview: payload.systemInstruction?.substring(0, 100),
            });
            const response = await handleText(payload, apiKey);
            res.json(response);
            return;
          }

          // Default to validation payload for compatibility with existing client.
          const payload = validateSchema.parse(req.body);
          const response = await handleValidate(payload, apiKey);
          res.json(response);
        } catch (error) {
          logger.error("💥 geminiProxy failed", error);
          if (error instanceof z.ZodError) {
            res.status(400).json({error: "Invalid payload", details: error.errors});
          } else if (error instanceof Error) {
            // Check if error is related to v1beta API version issue
            const errorMessage = error.message;
            logger.error("🔴 Error details", {
              errorMessage,
              errorStack: error.stack,
              errorName: error.name,
            });

            if (errorMessage.includes("v1beta") && errorMessage.includes("not found")) {
              logger.error("🚨 API version mismatch detected - SDK is using v1beta but model requires v1 API", {
                errorMessage,
                modelId: req.body?.mode === "identify" ? "gemini-1.5" :
                         req.body?.mode === "validate" ? "gemini-1.5" :
                         req.body?.mode === "text" || req.body?.mode === "story" ? "gemini-1.5" : "unknown",
                note: "This should not happen when using the v1 API",
                recommendation: "Verify the Cloud Function is deployed with apiVersion set to v1 and using gemini-2.0-flash.",
              });
            }
              
            // Log repeated gemini-1.5-flash not found errors specifically
            if (errorMessage.includes("gemini-1.5-flash") && errorMessage.includes("not found")) {
              logger.error("🚨 Repeated gemini-1.5-flash not found error detected", {
                errorMessage,
                modelId: req.body?.mode === "identify" ? "gemini-1.5" : 
                         req.body?.mode === "validate" ? "gemini-1.5" :
                         req.body?.mode === "text" || req.body?.mode === "story" ? "gemini-1.5" : "unknown",
                apiVersion: errorMessage.includes("v1beta") ? "v1beta" : "unknown",
                recommendation: "Model name may need to be gemini-2.0-flash for v1 API, or API version needs to be v1 instead of v1beta",
              });
            }
            res.status(500).json({error: error.message});
          } else {
            res.status(500).json({error: "Unknown error"});
          }
        }
      });
    },
);
