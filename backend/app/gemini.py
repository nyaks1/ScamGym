"""Gemini client wrapper.

Uses the official Google Gen AI Python SDK (``google-genai``). The API key is
read from the environment and never leaves the server.
"""

from __future__ import annotations

import asyncio
import logging

from google import genai
from google.genai import types

from app.config import Settings
from app.engine.prompts import build_scammer_instruction, build_triage_contents, build_triage_instruction
from app.engine.scoring import ACTION_LABELS
from app.scenarios.base import Scenario

logger = logging.getLogger("scamgym.gemini")


class GeminiUnavailableError(RuntimeError):
    """Raised when the server has no usable Gemini client."""


class GeminiService:
    def __init__(self, settings: Settings):
        self.model = settings.gemini_model
        self._client: genai.Client | None = None
        if settings.ai_enabled:
            try:
                self._client = genai.Client(
                    api_key=settings.gemini_api_key,
                    http_options=types.HttpOptions(timeout=45_000),
                )
            except Exception as exc:  # pragma: no cover - defensive
                logger.error("Gemini client could not start: %s", type(exc).__name__)

    @property
    def available(self) -> bool:
        return self._client is not None

    async def start_chat(self, scenario: Scenario):
        if self._client is None:
            raise GeminiUnavailableError("Gemini is not configured")
        config = types.GenerateContentConfig(
            system_instruction=build_scammer_instruction(scenario),
            temperature=0.9,
            top_p=0.95,
            max_output_tokens=350,
            tools=[types.Tool(function_declarations=_declarations(scenario))],
        )
        return self._client.aio.chats.create(model=self.model, config=config)

    async def explain_triage(self, kind: str, report: dict) -> str | None:
        """Optional plain-language explanation. Never changes the verdict."""
        if self._client is None:
            return None
        try:
            response = await asyncio.wait_for(
                self._client.aio.models.generate_content(
                    model=self.model,
                    contents=build_triage_contents(kind, report),
                    config=types.GenerateContentConfig(
                        system_instruction=build_triage_instruction(),
                        temperature=0.2,
                        max_output_tokens=450,
                    ),
                ),
                timeout=25,
            )
            text = (response.text or "").strip()
            return text[:1400] if text else None
        except Exception as exc:  # noqa: BLE001 - triage must still work offline
            logger.warning("Triage explanation unavailable: %s", type(exc).__name__)
            return None


def _declarations(scenario: Scenario) -> list[types.FunctionDeclaration]:
    return [
        types.FunctionDeclaration(
            name="plant_red_flag",
            description=(
                "Declare that your latest message planted one red flag from the scenario. "
                "Call this immediately after the message that introduces it."
            ),
            parameters=types.Schema(
                type=types.Type.OBJECT,
                properties={
                    "flag_id": types.Schema(
                        type=types.Type.STRING,
                        description="The id of the red flag you just planted.",
                        enum=[flag.id for flag in scenario.red_flags],
                    ),
                    "evidence": types.Schema(
                        type=types.Type.STRING,
                        description="A short exact quote from your latest message that shows the flag.",
                    ),
                },
                required=["flag_id"],
            ),
        ),
        types.FunctionDeclaration(
            name="record_user_action",
            description=(
                "Record something the learner just did. Only call this when their last message "
                "clearly shows the action. The server re-checks the transcript and may reject it."
            ),
            parameters=types.Schema(
                type=types.Type.OBJECT,
                properties={
                    "kind": types.Schema(
                        type=types.Type.STRING,
                        description="The action kind.",
                        enum=sorted(ACTION_LABELS),
                    ),
                    "evidence": types.Schema(
                        type=types.Type.STRING,
                        description="A short quote from the learner's message.",
                    ),
                },
                required=["kind"],
            ),
        ),
        types.FunctionDeclaration(
            name="score_round",
            description=(
                "Ask the server for the deterministic weigh-in when the learner stops, or when "
                "the scam has clearly succeeded or failed. You never calculate the score."
            ),
            parameters=types.Schema(
                type=types.Type.OBJECT,
                properties={},
            ),
        ),
    ]
