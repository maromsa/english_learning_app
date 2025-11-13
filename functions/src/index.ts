import * as functions from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions/v2";
import * as logger from "firebase-functions/logger";
import cors from "cors";
import {GoogleGenerativeAI, HarmBlockThreshold, HarmCategory} from "@google/generative-ai";
import {z} from "zod";

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
  systemInstruction: data.system_instruction, // Map to camelCase for internal use
}));

const textSchema = z.object({
  mode: z.literal("text"),
  prompt: z.string().min(1),
  system_instruction: z.string().optional(),
}).transform((data) => ({
  ...data,
  systemInstruction: data.system_instruction, // Map to camelCase for internal use
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
  
  // Initialize client - SDK v0.24.1 should use v1 API by default for gemini-1.5 models
  const client = new GoogleGenerativeAI(apiKey);
  
  // Build model config with ONLY snake_case system_instruction (never camelCase)
  // Explicitly construct the object to avoid any camelCase properties
  const modelConfig: any = {
    model: modelId,
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
  });
  
  // Use getGenerativeModel - gemini-1.5 model name ensures v1 API usage (not v1beta)
  logger.info("Calling getGenerativeModel", {
    modelId,
  });
  const model = client.getGenerativeModel(modelConfig);
  logger.info("Model created successfully", {
    modelId,
  });
  return model;
}

async function handleIdentify(payload: IdentifyPayload, apiKey: string) {
  // Use gemini-1.5 (not gemini-1.5-flash) - correct model name for v1 API
  const model = getModel("gemini-1.5", apiKey);
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
  const text = result.response.text()?.trim() ?? "";
  return {text};
}

async function handleValidate(payload: ValidatePayload, apiKey: string) {
  // Use gemini-1.5 (not gemini-1.5-flash) - correct model name for v1 API
  const model = getModel("gemini-1.5", apiKey);
  const prompt = `You are helping a child learn English words.
Does this picture clearly show the object "${payload.word}" as the main focus?
Answer strictly with "yes" or "no" and provide a confidence score between 0 and 1. Return JSON: {"approved": boolean, "confidence": number}.`;

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
  
  // Use gemini-1.5 (not gemini-1.5-flash) - correct model name for v1 API
  const model = getModel("gemini-1.5", apiKey, payload.systemInstruction);
  
  const generateContentPayload = {
    contents: [{
      role: "user",
      parts: [
        {text: payload.prompt},
      ],
    }],
  };
  
  logger.info("Calling generateContent", {
    payload: JSON.stringify(generateContentPayload),
    payloadKeys: Object.keys(generateContentPayload),
  });
  
  const result = await model.generateContent(generateContentPayload);
  const text = result.response.text()?.trim() ?? "";
  return {text};
}

// Export for testing
export {handleText, getModel};

export const geminiProxy = functions.onRequest(
    {cors: true, secrets: ["GEMINI_API_KEY"]},
    (req, res) => {
      corsHandler(req, res, async () => {
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

        try {
          logger.info("geminiProxy received request", {
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
            logger.info("Parsed payload for text/story mode", {
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
          logger.error("geminiProxy failed", error);
          if (error instanceof z.ZodError) {
            res.status(400).json({error: "Invalid payload", details: error.errors});
          } else if (error instanceof Error) {
            // Check if error is related to v1beta API version issue
            const errorMessage = error.message;
            if (errorMessage.includes("v1beta") && errorMessage.includes("not found")) {
              logger.error("API version mismatch detected - SDK is using v1beta but model requires v1 API", {
                errorMessage,
                modelId: req.body?.mode === "identify" ? "gemini-1.5" : 
                         req.body?.mode === "validate" ? "gemini-1.5" :
                         req.body?.mode === "text" || req.body?.mode === "story" ? "gemini-1.5" : "unknown",
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
