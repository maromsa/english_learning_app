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
  systemInstruction: z.string().optional(),
});

const textSchema = z.object({
  mode: z.literal("text"),
  prompt: z.string().min(1),
  systemInstruction: z.string().optional(),
});

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

function getModel(modelId: string, apiKey: string) {
  const client = new GoogleGenerativeAI(apiKey);
  const modelConfig = {
    model: modelId,
    safetySettings,
  };
  return client.getGenerativeModel(modelConfig);
}

async function handleIdentify(payload: IdentifyPayload, apiKey: string) {
  const model = getModel("gemini-1.5-flash", apiKey);
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
  const model = getModel("gemini-1.5-flash", apiKey);
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
  const model = getModel("gemini-1.5-flash", apiKey);
  
  // Build the prompt - prepend systemInstruction if provided
  // The SDK version 0.24.1 may not support systemInstruction as a separate field,
  // so we include it in the prompt content to avoid API errors
  let promptText = payload.prompt;
  if (payload.systemInstruction && payload.systemInstruction.trim().length > 0) {
    promptText = `${payload.systemInstruction}\n\n${payload.prompt}`;
  }
  
  const result = await model.generateContent({
    contents: [{
      role: "user",
      parts: [
        {text: promptText},
      ],
    }],
  });
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
          if (req.body?.mode === "identify") {
            const payload = identifySchema.parse(req.body);
            const response = await handleIdentify(payload, apiKey);
            res.json(response);
            return;
          }

          if (req.body?.mode === "story" || req.body?.mode === "text") {
            const payload = (req.body.mode === "story" ? storySchema : textSchema).parse(req.body);
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
            res.status(500).json({error: error.message});
          } else {
            res.status(500).json({error: "Unknown error"});
          }
        }
      });
    },
);
