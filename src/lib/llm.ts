import type { LLMMessage, LLMProviderConfig } from "@/types";
import { decryptApiKey } from "./crypto";

export async function callLLM(
  messages: LLMMessage[],
  config: LLMProviderConfig,
): Promise<string> {
  if (!config.encryptedApiKey) {
    throw new Error("API キーが設定されていません");
  }

  const apiKey = await decryptApiKey(config.encryptedApiKey);

  if (config.provider === "anthropic") {
    return callAnthropic(messages, config.model, apiKey);
  }
  return callOpenAI(messages, config.model, apiKey);
}

async function callAnthropic(
  messages: LLMMessage[],
  model: string,
  apiKey: string,
): Promise<string> {
  const systemMessages = messages.filter((m) => m.role === "system");
  const nonSystemMessages = messages.filter((m) => m.role !== "system");

  const body: Record<string, unknown> = {
    model,
    max_tokens: 4096,
    messages: nonSystemMessages.map((m) => ({
      role: m.role,
      content: m.content,
    })),
  };
  if (systemMessages.length > 0) {
    body.system = systemMessages.map((m) => m.content).join("\n\n");
  }

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      "anthropic-dangerous-direct-browser-access": "true",
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Anthropic API エラー: ${res.status} ${err}`);
  }

  const data = await res.json();
  const textBlock = data.content?.find(
    (b: { type: string }) => b.type === "text",
  );
  return textBlock?.text ?? "";
}

async function callOpenAI(
  messages: LLMMessage[],
  model: string,
  apiKey: string,
): Promise<string> {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      messages: messages.map((m) => ({ role: m.role, content: m.content })),
      max_tokens: 4096,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`OpenAI API エラー: ${res.status} ${err}`);
  }

  const data = await res.json();
  return data.choices?.[0]?.message?.content ?? "";
}
