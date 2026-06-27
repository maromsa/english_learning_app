import {handleTts, isRateLimited, verifyAuth} from "../index";

jest.mock("@google/generative-ai");

describe("verifyAuth", () => {
  test("returns null when the Authorization header is missing", async () => {
    expect(await verifyAuth(undefined)).toBeNull();
  });

  test("returns null when the header is not a Bearer token", async () => {
    expect(await verifyAuth("Basic abc123")).toBeNull();
  });

  test("returns null for an invalid Bearer token", async () => {
    // firebase-admin cannot verify a garbage token in the test environment,
    // so verifyAuth must swallow the error and report null (=> HTTP 401).
    expect(await verifyAuth("Bearer not-a-real-token")).toBeNull();
  });
});

describe("isRateLimited", () => {
  test("allows requests under the limit and blocks the excess", () => {
    const uid = `rate-test-${Date.now()}`;
    const now = Date.now();

    for (let i = 0; i < 30; i++) {
      expect(isRateLimited(uid, now + i)).toBe(false);
    }
    expect(isRateLimited(uid, now + 100)).toBe(true);
  });

  test("frees capacity after the window slides past old requests", () => {
    const uid = `rate-window-${Date.now()}`;
    const now = Date.now();

    for (let i = 0; i < 30; i++) {
      expect(isRateLimited(uid, now)).toBe(false);
    }
    expect(isRateLimited(uid, now)).toBe(true);

    // 61 seconds later the old requests have expired.
    expect(isRateLimited(uid, now + 61_000)).toBe(false);
  });

  test("tracks users independently", () => {
    const now = Date.now();
    const uidA = `rate-a-${now}`;
    const uidB = `rate-b-${now}`;

    for (let i = 0; i < 30; i++) {
      isRateLimited(uidA, now);
    }
    expect(isRateLimited(uidA, now)).toBe(true);
    expect(isRateLimited(uidB, now)).toBe(false);
  });
});

describe("handleTts", () => {
  const mockApiKey = "tts-test-key";
  let fetchSpy: jest.SpyInstance;

  beforeEach(() => {
    fetchSpy = jest.spyOn(global, "fetch" as never);
  });

  afterEach(() => {
    fetchSpy.mockRestore();
  });

  function mockFetchResponse(status: number, body: unknown) {
    fetchSpy.mockResolvedValue({
      ok: status >= 200 && status < 300,
      status,
      json: async () => body,
    } as Response);
  }

  test("returns audioContent on success", async () => {
    mockFetchResponse(200, {audioContent: "bW9jaw=="});

    const result = await handleTts(
        {
          mode: "tts",
          ssml: "<speak>hi</speak>",
          languageCode: "he-IL",
          speakingRate: 0.85,
          pitch: 2,
          volumeGainDb: 2,
        },
        mockApiKey,
    );

    expect(result).toEqual({audioContent: "bW9jaw=="});

    // Verify the request body forwarded the SSML and voice settings.
    const [url, init] = fetchSpy.mock.calls[0];
    expect(String(url)).toContain("texttospeech.googleapis.com");
    expect(String(url)).toContain(mockApiKey);
    const body = JSON.parse((init as RequestInit).body as string);
    expect(body.input).toEqual({ssml: "<speak>hi</speak>"});
    expect(body.voice.languageCode).toBe("he-IL");
    expect(body.audioConfig.speakingRate).toBe(0.85);
  });

  test("uses plain text input when ssml is absent", async () => {
    mockFetchResponse(200, {audioContent: "bW9jaw=="});

    await handleTts(
        {
          mode: "tts",
          text: "hello",
          languageCode: "en-US",
          speakingRate: 1,
          pitch: 0,
          volumeGainDb: 0,
        },
        mockApiKey,
    );

    const [, init] = fetchSpy.mock.calls[0];
    const body = JSON.parse((init as RequestInit).body as string);
    expect(body.input).toEqual({text: "hello"});
  });

  test("throws when the TTS API responds with an error status", async () => {
    mockFetchResponse(403, {error: "denied"});

    await expect(handleTts(
        {
          mode: "tts",
          text: "hello",
          languageCode: "en-US",
          speakingRate: 1,
          pitch: 0,
          volumeGainDb: 0,
        },
        mockApiKey,
    )).rejects.toThrow("403");
  });

  test("throws when the TTS API returns no audio", async () => {
    mockFetchResponse(200, {});

    await expect(handleTts(
        {
          mode: "tts",
          text: "hello",
          languageCode: "en-US",
          speakingRate: 1,
          pitch: 0,
          volumeGainDb: 0,
        },
        mockApiKey,
    )).rejects.toThrow("no audio");
  });
});
