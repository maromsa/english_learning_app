import {GoogleGenerativeAI} from "@google/generative-ai";
import {getModel, handleText} from "../index";

// Mock the Google Generative AI SDK
jest.mock("@google/generative-ai");

describe("systemInstruction handling", () => {
  const mockApiKey = "test-api-key";
  const mockGenerateContent = jest.fn();
  const mockText = jest.fn();

  beforeEach(() => {
    jest.clearAllMocks();

    // Setup mock chain
    mockText.mockReturnValue("test response");
    mockGenerateContent.mockResolvedValue({
      response: {
        text: mockText,
      },
    });

    const mockModel = {
      generateContent: mockGenerateContent,
    };

    const mockClient = {
      getGenerativeModel: jest.fn().mockReturnValue(mockModel),
    };

    (GoogleGenerativeAI as jest.MockedClass<typeof GoogleGenerativeAI>).mockImplementation(
        () => mockClient as any,
    );
  });

  test("getModel should not accept systemInstruction parameter", () => {
    getModel("gemini-1.5-flash", mockApiKey);

    const GoogleGenerativeAIClass = GoogleGenerativeAI as jest.MockedClass<typeof GoogleGenerativeAI>;
    const mockClientInstance = GoogleGenerativeAIClass.mock.results[0]?.value;
    const getGenerativeModelCall = mockClientInstance?.getGenerativeModel;

    // Verify getGenerativeModel was called
    expect(getGenerativeModelCall).toHaveBeenCalled();

    // Verify the model config does NOT contain systemInstruction
    const modelConfig = getGenerativeModelCall?.mock.calls[0]?.[0];
    expect(modelConfig).not.toHaveProperty("systemInstruction");
    expect(modelConfig).toHaveProperty("model", "gemini-1.5-flash");
    expect(modelConfig).toHaveProperty("safetySettings");
  });

  test("handleText should pass systemInstruction to generateContent when provided", async () => {
    const payload = {
      mode: "text" as const,
      prompt: "Test prompt",
      systemInstruction: "Test system instruction",
    };

    await handleText(payload, mockApiKey);

    // Verify getGenerativeModel was called WITHOUT systemInstruction
    const GoogleGenerativeAIClass = GoogleGenerativeAI as jest.MockedClass<typeof GoogleGenerativeAI>;
    const mockClientInstance = GoogleGenerativeAIClass.mock.results[0]?.value;
    const getGenerativeModelCall = mockClientInstance?.getGenerativeModel;
    expect(getGenerativeModelCall).toHaveBeenCalled();
    const modelConfig = getGenerativeModelCall?.mock.calls[0]?.[0];
    expect(modelConfig).not.toHaveProperty("systemInstruction");

    // Verify generateContent was called
    expect(mockGenerateContent).toHaveBeenCalledTimes(1);

    // Verify systemInstruction was passed to generateContent
    const generateContentCall = mockGenerateContent.mock.calls[0]?.[0];
    expect(generateContentCall).toHaveProperty("systemInstruction");
    expect(generateContentCall.systemInstruction).toBe("Test system instruction");
    expect(generateContentCall).toHaveProperty("contents");
    expect(generateContentCall.contents).toHaveLength(1);
    expect(generateContentCall.contents[0].parts[0].text).toBe("Test prompt");
  });

  test("handleText should work without systemInstruction", async () => {
    const payload = {
      mode: "text" as const,
      prompt: "Test prompt",
      // No systemInstruction
    };

    await handleText(payload, mockApiKey);

    // Verify generateContent was called
    expect(mockGenerateContent).toHaveBeenCalledTimes(1);

    // Verify systemInstruction was NOT passed when not provided
    const generateContentCall = mockGenerateContent.mock.calls[0]?.[0];
    expect(generateContentCall).not.toHaveProperty("systemInstruction");
    expect(generateContentCall).toHaveProperty("contents");
  });

  test("handleText should handle story mode with systemInstruction", async () => {
    const payload = {
      mode: "story" as const,
      prompt: "Create a story",
      systemInstruction: "You are a creative storyteller",
    };

    await handleText(payload, mockApiKey);

    // Verify getGenerativeModel was called WITHOUT systemInstruction
    const GoogleGenerativeAIClass = GoogleGenerativeAI as jest.MockedClass<typeof GoogleGenerativeAI>;
    const mockClientInstance = GoogleGenerativeAIClass.mock.results[0]?.value;
    const getGenerativeModelCall = mockClientInstance?.getGenerativeModel;
    expect(getGenerativeModelCall).toHaveBeenCalled();
    const modelConfig = getGenerativeModelCall?.mock.calls[0]?.[0];
    expect(modelConfig).not.toHaveProperty("systemInstruction");

    expect(mockGenerateContent).toHaveBeenCalledTimes(1);
    const generateContentCall = mockGenerateContent.mock.calls[0]?.[0];
    expect(generateContentCall).toHaveProperty("systemInstruction");
    expect(generateContentCall.systemInstruction).toBe("You are a creative storyteller");
    expect(generateContentCall.contents[0].parts[0].text).toBe("Create a story");
  });

  test("should return text response correctly", async () => {
    mockText.mockReturnValue("  response text  ");

    const payload = {
      mode: "text" as const,
      prompt: "Test prompt",
    };

    const result = await handleText(payload, mockApiKey);

    expect(result).toEqual({text: "response text"});
    expect(mockText).toHaveBeenCalled();
  });
});
