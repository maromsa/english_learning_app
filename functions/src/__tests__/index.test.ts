import {GoogleGenerativeAI} from "@google/generative-ai";
import {getModel, handleText} from "../index";

// Mock the Google Generative AI SDK
jest.mock("@google/generative-ai");

describe("systemInstruction handling", () => {
  const mockApiKey = "test-api-key";
  const mockGenerateContent = jest.fn();
  const mockText = jest.fn();
  let mockModel: {generateContent: jest.Mock};
  let mockClient: {getGenerativeModel: jest.Mock};

  beforeEach(() => {
    jest.clearAllMocks();

    // Setup mock chain
    mockText.mockReturnValue("test response");
    mockGenerateContent.mockResolvedValue({
      response: {
        text: mockText,
      },
    });
    mockModel = {
      generateContent: mockGenerateContent,
    };

    mockClient = {
      getGenerativeModel: jest.fn().mockReturnValue(mockModel),
    };

    (GoogleGenerativeAI as jest.MockedClass<typeof GoogleGenerativeAI>).mockImplementation(
        () => mockClient as any,
    );
  });

  test("getModel should not include system_instruction when not provided", () => {
    getModel("gemini-1.5", mockApiKey);

    const GoogleGenerativeAIClass = GoogleGenerativeAI as jest.MockedClass<typeof GoogleGenerativeAI>;
    const mockClientInstance = GoogleGenerativeAIClass.mock.results[0]?.value;
    const getGenerativeModelCall = mockClientInstance?.getGenerativeModel;

    // Verify getGenerativeModel was called
    expect(getGenerativeModelCall).toHaveBeenCalled();

    // Verify the model config does NOT contain system_instruction when not provided
    const modelConfig = getGenerativeModelCall?.mock.calls[0]?.[0];
    expect(modelConfig).not.toHaveProperty("systemInstruction");
    expect(modelConfig).not.toHaveProperty("system_instruction");
    expect(modelConfig).toHaveProperty("model", "gemini-2.0-flash"); // Updated to gemini-2.0-flash for v1 API
    expect(modelConfig).toHaveProperty("safetySettings");
    
    // Verify GoogleGenerativeAI was initialized with the API key
    const constructorCall = GoogleGenerativeAIClass.mock.calls[0];
    expect(constructorCall[0]).toBe(mockApiKey);
    
    // Verify getGenerativeModel was called with the v1 API version
    const requestOptions = getGenerativeModelCall?.mock.calls[0]?.[1];
    expect(requestOptions).toEqual(expect.objectContaining({apiVersion: "v1"}));
  });

  test("getModel should include system_instruction when provided", () => {
    getModel("gemini-1.5", mockApiKey, "Test system instruction");

    const GoogleGenerativeAIClass = GoogleGenerativeAI as jest.MockedClass<typeof GoogleGenerativeAI>;
    const mockClientInstance = GoogleGenerativeAIClass.mock.results[0]?.value;
    const getGenerativeModelCall = mockClientInstance?.getGenerativeModel;

    // Verify getGenerativeModel was called
    expect(getGenerativeModelCall).toHaveBeenCalled();

    // Verify the model config DOES contain system_instruction (snake_case) when provided
    // We use snake_case directly to match the API spec
    const modelConfig = getGenerativeModelCall?.mock.calls[0]?.[0];
    expect(modelConfig).toHaveProperty("system_instruction", "Test system instruction");
    expect(modelConfig).not.toHaveProperty("systemInstruction");
    expect(modelConfig).toHaveProperty("model", "gemini-2.0-flash"); // Updated to gemini-2.0-flash for v1 API
    expect(modelConfig).toHaveProperty("safetySettings");
    
    // Verify GoogleGenerativeAI was initialized with the API key
    const constructorCall = GoogleGenerativeAIClass.mock.calls[0];
    expect(constructorCall[0]).toBe(mockApiKey);
    
    // Verify getGenerativeModel was called with the v1 API version
    const requestOptions = getGenerativeModelCall?.mock.calls[0]?.[1];
    expect(requestOptions).toEqual(expect.objectContaining({apiVersion: "v1"}));
  });

  test("handleText should pass systemInstruction to getModel when provided", async () => {
    const payload = {
      mode: "text" as const,
      prompt: "Test prompt",
      systemInstruction: "Test system instruction",
    };

    await handleText(payload, mockApiKey);

    // Verify getGenerativeModel was called WITH system_instruction (snake_case)
    // We use snake_case directly to match the API spec
    const GoogleGenerativeAIClass = GoogleGenerativeAI as jest.MockedClass<typeof GoogleGenerativeAI>;
    const mockClientInstance = GoogleGenerativeAIClass.mock.results[0]?.value;
    const getGenerativeModelCall = mockClientInstance?.getGenerativeModel;
    expect(getGenerativeModelCall).toHaveBeenCalled();
    const modelConfig = getGenerativeModelCall?.mock.calls[0]?.[0];
    expect(modelConfig).toHaveProperty("system_instruction", "Test system instruction");
    expect(modelConfig).not.toHaveProperty("systemInstruction");

    // Verify generateContent was called WITHOUT systemInstruction (it's set at model level)
    expect(mockGenerateContent).toHaveBeenCalledTimes(1);
    const generateContentCall = mockGenerateContent.mock.calls[0]?.[0];
    expect(generateContentCall).not.toHaveProperty("systemInstruction");
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

    // Verify getGenerativeModel was called WITH system_instruction (snake_case)
    // We use snake_case directly to match the API spec
    const GoogleGenerativeAIClass = GoogleGenerativeAI as jest.MockedClass<typeof GoogleGenerativeAI>;
    const mockClientInstance = GoogleGenerativeAIClass.mock.results[0]?.value;
    const getGenerativeModelCall = mockClientInstance?.getGenerativeModel;
    expect(getGenerativeModelCall).toHaveBeenCalled();
    const modelConfig = getGenerativeModelCall?.mock.calls[0]?.[0];
    expect(modelConfig).toHaveProperty("system_instruction", "You are a creative storyteller");
    expect(modelConfig).not.toHaveProperty("systemInstruction");
    
    // Verify GoogleGenerativeAI was initialized with the API key
    const constructorCall = GoogleGenerativeAIClass.mock.calls[0];
    expect(constructorCall[0]).toBe(mockApiKey);
    
    // Verify getGenerativeModel was called with the v1 API version
    const requestOptions = getGenerativeModelCall?.mock.calls[0]?.[1];
    expect(requestOptions).toEqual(expect.objectContaining({apiVersion: "v1"}));

    expect(mockGenerateContent).toHaveBeenCalledTimes(1);
    const generateContentCall = mockGenerateContent.mock.calls[0]?.[0];
    expect(generateContentCall).not.toHaveProperty("systemInstruction");
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

  test("handleText retries with fallback when a model not found error occurs", async () => {
    const notFoundError = new Error("[GoogleGenerativeAI Error]: Error fetching from https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent: [404 Not Found] models/gemini-1.5-flash is not found for API version v1beta, or is not supported for generateContent.");
    mockGenerateContent.mockRejectedValueOnce(notFoundError);
    mockText.mockReturnValue("fallback response");
    mockGenerateContent.mockResolvedValueOnce({
      response: {
        text: mockText,
      },
    });

    const payload = {
      mode: "text" as const,
      prompt: "Test prompt",
    };

    const result = await handleText(payload, mockApiKey);

    expect(result).toEqual({text: "fallback response"});
    expect(mockClient.getGenerativeModel).toHaveBeenCalledTimes(2);
    expect(mockGenerateContent).toHaveBeenCalledTimes(2);
  });

  test("handleText surfaces non-model-not-found errors without retrying", async () => {
    const unexpectedError = new Error("Network down");
    mockGenerateContent.mockRejectedValueOnce(unexpectedError);

    const payload = {
      mode: "text" as const,
      prompt: "Test prompt",
    };

    await expect(handleText(payload, mockApiKey)).rejects.toThrow("Network down");
    expect(mockClient.getGenerativeModel).toHaveBeenCalledTimes(1);
    expect(mockGenerateContent).toHaveBeenCalledTimes(1);
  });
});
