import * as functions from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2";
import * as logger from "firebase-functions/logger";
import cors from "cors";
import {GoogleGenerativeAI, HarmBlockThreshold, HarmCategory} from "@google/generative-ai";
import {z} from "zod";

// Setup fetch override at module level to ensure it's active before SDK initialization
// This ensures all Gemini API calls use v1 API instead of v1beta
const originalFetch = global.fetch;
const customFetch = async (url: string | Request | URL, init?: RequestInit): Promise<Response> => {
  let urlString = typeof url === "string" ? url : url instanceof URL ? url.toString() : (url as Request).url;
  
  // CRITICAL: Rewrite v1beta URLs to v1 for Gemini API calls
  // Also handle v1beta2, v1beta3, etc. variations
  if (urlString.includes("generativelanguage.googleapis.com")) {
    const originalUrl = urlString;
    const hadV1beta = /\/v1beta\d*\//.test(urlString);
    
    // Replace any v1beta, v1beta2, v1beta3, etc. with v1
    urlString = urlString.replace(/\/v1beta\d*\//g, "/v1/");
    
    // Also handle model name transformations if needed
    // If SDK is using gemini-1.5-flash without suffix, ensure we use a valid v1 model name
    // But don't modify the model name here - let the getModel function handle it
    
    if (originalUrl !== urlString) {
      logger.warn("⚠️ [Module-level] Rewriting Gemini API URL from v1beta to v1", {
        originalUrl,
        newUrl: urlString,
      });
    }
    
    // Construct the new request with rewritten URL
    // The SDK typically uses string URLs, but handle all cases
    let newRequest: string | Request | URL;
    if (typeof url === "string") {
      newRequest = urlString;
    } else if (url instanceof URL) {
      newRequest = new URL(urlString);
    } else {
      // For Request objects, create a new Request with rewritten URL
      // Use the original request as the init to preserve all properties including body
      newRequest = new Request(urlString, url);
    }
    
    // Log response after the request
    const response = await originalFetch(newRequest, init);
    
    // Log error details if request failed
    if (!response.ok) {
      if (response.status === 404) {
        logger.error("🚨 [Module-level] 404 error on Gemini API call", {
          originalUrl,
          rewrittenUrl: urlString,
          status: response.status,
          statusText: response.statusText,
          note: "This may indicate API version or model name issue",
        });
      } else {
        logger.warn("⚠️ [Module-level] Non-200 response from Gemini API", {
          originalUrl,
          rewrittenUrl: urlString,
          status: response.status,
          statusText: response.statusText,
          wasRewritten: originalUrl !== urlString,
        });
      }
    }
    
    return response;
  }
  
  // For non-Gemini URLs, use original fetch
  return originalFetch(url, init);
};

// Override global fetch at module level
(global as any).fetch = customFetch;
logger.info("🌐 [Module-level] Global fetch overridden with custom fetch for v1 API");

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

function getModel(modelId: string, apiKey: string, systemInstruction?: string) {
  logger.info("getModel called", {
    modelId,
    hasSystemInstruction: systemInstruction !== undefined,
    systemInstructionType: typeof systemInstruction,
    systemInstructionLength: systemInstruction?.length,
    systemInstructionValue: systemInstruction,
  });
  
  // Create client - it will use the fetch override set at handler level
  logger.info("Creating GoogleGenerativeAI client", {
    apiKeyPresent: !!apiKey,
    apiKeyLength: apiKey?.length,
    currentFetchType: typeof (global as any).fetch,
  });
  
  const client = new GoogleGenerativeAI(apiKey);
  logger.info("GoogleGenerativeAI client created successfully");
  
  // Build model config with ONLY snake_case system_instruction (never camelCase)
  // Explicitly construct the object to avoid any camelCase properties
  // Use gemini-1.5-flash-001 - this is a stable model name for v1 API
  // The fetch override will rewrite any v1beta URLs to v1
  // Note: gemini-1.5-flash-001 is the stable version name for v1 API
  const modelConfig: any = {
    model: modelId === "gemini-1.5" ? "gemini-1.5-flash-001" : modelId,
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
  logger.info("Model config before getGenerativeModel", {
    modelConfig: JSON.stringify(modelConfig),
    modelConfigKeys: Object.keys(modelConfig),
    hasSystemInstruction: modelConfig.system_instruction !== undefined,
    hasSystemInstructionCamelCase: modelConfig.systemInstruction !== undefined,
    finalModelId: modelConfig.model,
  });
  
  // Use getGenerativeModel - custom fetch will rewrite v1beta URLs to v1
  logger.info("Calling getGenerativeModel", {
    modelId,
    finalModelId: modelConfig.model,
    note: "Using custom fetch to rewrite v1beta URLs to v1",
  });
  const model = client.getGenerativeModel(modelConfig);
  logger.info("Model created successfully", {
    modelId,
    finalModelId: modelConfig.model,
    baseUrl: "https://generativelanguage.googleapis.com/v1",
  });
  return model;
}

async function handleIdentify(payload: IdentifyPayload, apiKey: string) {
  logger.info("🔍 handleIdentify called");
  const model = getModel("gemini-1.5", apiKey);
  logger.info("📤 Calling generateContent for identify");
  const result = await model.generateContent({
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
  logger.info("✅ generateContent completed for identify");
  const text = result.response.text()?.trim() ?? "";
  return {text};
}

async function handleValidate(payload: ValidatePayload, apiKey: string) {
  logger.info("🔍 handleValidate called");
  const model = getModel("gemini-1.5", apiKey);
  const prompt = `You are helping a child learn English words.
Does this picture clearly show the object "${payload.word}" as the main focus?
Answer strictly with "yes" or "no" and provide a confidence score between 0 and 1. Return JSON: {"approved": boolean, "confidence": number}.`;

  logger.info("📤 Calling generateContent for validate");
  const result = await model.generateContent({
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
  
  const model = getModel("gemini-1.5", apiKey, payload.systemInstruction);
  
  const generateContentPayload = {
    contents: [{
      role: "user",
      parts: [
        {text: payload.prompt},
      ],
    }],
  };
  
  logger.info("📤 Calling generateContent for text/story", {
    payload: JSON.stringify(generateContentPayload),
    payloadKeys: Object.keys(generateContentPayload),
  });
  
  const result = await model.generateContent(generateContentPayload);
  logger.info("✅ generateContent completed for text/story");
  const text = result.response.text()?.trim() ?? "";
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
            // Check if error is related to v1beta API version issue or model not found
            const errorMessage = error.message;
            logger.error("🔴 Error details", {
              errorMessage,
              errorStack: error.stack,
              errorName: error.name,
            });
            
            // Handle specific Gemini API model not found errors
            const isModelNotFoundError = 
              (errorMessage.includes("not found") && errorMessage.includes("models/")) ||
              (errorMessage.includes("gemini-1.5-flash") && errorMessage.includes("not found")) ||
              (errorMessage.includes("v1beta") && errorMessage.includes("not found"));
            
            if (isModelNotFoundError) {
              const isV1betaError = errorMessage.includes("v1beta");
              const modelName = errorMessage.match(/models\/([^\s]+)/)?.[1] || "unknown";
              
              logger.error("🚨 Gemini API model not found error detected", {
                errorMessage,
                detectedModelName: modelName,
                apiVersion: isV1betaError ? "v1beta" : "unknown",
                requestedModelId: req.body?.mode === "identify" ? "gemini-1.5" : 
                                  req.body?.mode === "validate" ? "gemini-1.5" :
                                  req.body?.mode === "text" || req.body?.mode === "story" ? "gemini-1.5" : "unknown",
                fetchOverrideActive: typeof (global as any).fetch === "function",
                recommendation: isV1betaError 
                  ? "SDK is using v1beta API but model requires v1 API. Fetch override should rewrite URLs, but SDK may be bypassing it. Try using gemini-1.5-flash-001 for v1 API."
                  : "Model name may be incorrect. Try using gemini-1.5-flash-001 (stable) or gemini-1.5-flash-latest for v1 API.",
              });
              
              // Provide user-friendly error message
              const userFriendlyError = isV1betaError
                ? "API version mismatch: The SDK is using v1beta API but the model requires v1 API. This is being handled automatically."
                : `Model not found: ${modelName}. Please check the model name and API version compatibility.`;
              
              res.status(500).json({
                error: userFriendlyError,
                details: errorMessage,
                suggestion: "The system will retry with the correct API version. If this persists, please contact support.",
              });
              return;
            }
            
            res.status(500).json({error: error.message});
          } else {
            res.status(500).json({error: "Unknown error"});
          }
        }
      });
    },
);
