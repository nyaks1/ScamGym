"""Round orchestration: Gemini writes the scam, plain code records and grades."""

from __future__ import annotations

import asyncio
import logging
import time
from urllib.parse import urlsplit

from google.genai import types

from app.engine.rounds import Round, RoundManager
from app.engine.scoring import (
    ACTION_LABELS,
    Action,
    action_supported,
    compute_score,
    detect_actions,
    otp_was_requested,
)
from app.engine.safety import looks_like_refusal, sanitize_scammer_text
from app.gemini import GeminiService, GeminiUnavailableError
from app.scenarios.base import Scenario

logger = logging.getLogger("scamgym.trainer")

FALLBACK_LINE = "Sorry, I lost your last message. Are you still there? I can only hold this open for a few more minutes."
CLOSING_FALLBACK_LINE = "Alright, I will close this case from my side."


class AIUnavailableError(RuntimeError):
    """The server has no Gemini key, or Gemini is temporarily unreachable."""


class RoundNotFoundError(KeyError):
    """No such round (expired or never existed)."""


class RoundConflictError(RuntimeError):
    """The round is finished, or the turn limit has been reached."""


class Trainer:
    def __init__(self, gemini: GeminiService, rounds: RoundManager):
        self.gemini = gemini
        self.rounds = rounds

    # ---- public API -----------------------------------------------------

    def start(self, scenario: Scenario) -> dict:
        round = self.rounds.create(scenario)
        return {
            "round_id": round.id,
            "scenario": scenario.public(),
            "opening": scenario.opening,
            "turn": 0,
            "max_turns": scenario.max_turns,
            "status": round.status,
        }

    def state(self, round_id: str) -> dict:
        return self._get(round_id).public_state()

    async def send(self, round_id: str, text: str) -> dict:
        round = self._get(round_id)
        text = (text or "").strip()[:1200]
        if not text:
            raise ValueError("Message is empty")

        async with round.lock:
            if round.status != "active":
                raise RoundConflictError("This round is already finished. Weigh in or start a new one.")
            if round.turns >= round.scenario.max_turns:
                raise RoundConflictError("Turn limit reached. Weigh in to see your score.")

            otp_requested = self._otp_requested(round)
            before_len = len(round.transcript)
            before_planted = set(round.planted)
            before_actions = dict(round.actions)
            before_status = round.status
            before_score = round.score

            round.transcript.append({"role": "user", "text": text})
            for action in detect_actions(text, otp_requested=otp_requested):
                round.actions.setdefault(action.kind, action)

            try:
                if round.chat is None:
                    prior_turns = round.transcript[1:before_len]
                    round.chat = await self.gemini.start_chat(
                        round.scenario,
                        history=prior_turns or None,
                    )
                reply = await self._exchange(round, text)
            except GeminiUnavailableError as exc:
                self._rollback(
                    round, before_len, before_planted, before_actions, before_status, before_score
                )
                raise AIUnavailableError("Gemini is not configured on this server") from exc
            except Exception:
                self._rollback(
                    round, before_len, before_planted, before_actions, before_status, before_score
                )
                raise

            reply = sanitize_scammer_text(reply, round.scenario)
            if not reply or looks_like_refusal(reply):
                reply = CLOSING_FALLBACK_LINE if round.status == "scored" else FALLBACK_LINE

            round.transcript.append({"role": "scammer", "text": reply})
            round.turns += 1
            if round.turns >= round.scenario.max_turns and round.status == "active":
                round.status = "ended"
            if round.score is not None:
                round.score = self._compute(round)
            round.updated_at = time.time()

            return {
                "round_id": round.id,
                "reply": reply,
                "turn": round.turns,
                "max_turns": round.scenario.max_turns,
                "status": round.status,
                "score": round.score,
                "limit_reached": round.status == "ended",
            }

    async def score(self, round_id: str) -> dict:
        round = self._get(round_id)
        async with round.lock:
            if round.score is None:
                round.score = self._compute(round)
            round.status = "scored"
            round.updated_at = time.time()
            return round.score

    async def record_event(self, round_id: str, kind: str, url: str) -> dict:
        round = self._get(round_id)
        async with round.lock:
            if round.status != "active":
                raise RoundConflictError("This round is already finished.")
            if kind != "link_clicked":
                raise ValueError("Unsupported event")
            host = ""
            try:
                host = urlsplit(url).hostname or ""
            except ValueError:
                host = ""
            round.actions.setdefault(
                "clicked_link",
                Action(kind="clicked_link", source="client", evidence=host or "[unparseable link]"),
            )
            round.updated_at = time.time()
            return {"ok": True, "recorded": "clicked_link"}

    def delete(self, round_id: str) -> None:
        self.rounds.delete(round_id)

    # ---- internals ------------------------------------------------------

    def _get(self, round_id: str) -> Round:
        try:
            return self.rounds.get(round_id)
        except KeyError as exc:
            raise RoundNotFoundError(round_id) from exc

    def _otp_requested(self, round: Round) -> bool:
        return otp_was_requested(
            item["text"] for item in round.transcript if item["role"] == "scammer"
        )

    def _compute(self, round: Round) -> dict:
        return compute_score(
            round.scenario,
            planted_flag_ids=round.planted,
            user_messages=[item["text"] for item in round.transcript if item["role"] == "user"],
            actions=round.actions.values(),
            turn_count=round.turns,
        )

    async def _exchange(self, round: Round, text: str) -> str:
        chat = round.chat
        assert chat is not None
        response = await asyncio.wait_for(chat.send_message(text), timeout=50)
        texts: list[str] = []

        for _ in range(3):
            calls = list(response.function_calls or [])
            if not calls:
                break
            parts = []
            for call in calls:
                result = self._handle_tool(round, call, text)
                parts.append(
                    types.Part.from_function_response(
                        name=call.name or "unknown_tool",
                        response=result,
                    )
                )
            current = _response_text(response)
            if current:
                texts.append(current)
            response = await asyncio.wait_for(chat.send_message(parts), timeout=50)

        final = _response_text(response)
        if final:
            texts.append(final)
        return texts[-1] if texts else ""

    def _handle_tool(self, round: Round, call, user_text: str) -> dict:
        name = call.name or ""
        args = dict(call.args or {})

        if name == "plant_red_flag":
            flag_id = str(args.get("flag_id") or args.get("flagId") or "").strip()
            flag = round.scenario.flag(flag_id)
            if flag is None:
                return {"ok": False, "error": f"unknown flag_id {flag_id!r}"}
            if flag_id in round.planted:
                return {"ok": True, "already_planted": True, "flag_id": flag_id}
            round.planted.add(flag_id)
            remaining = [item.id for item in round.scenario.red_flags if item.id not in round.planted]
            return {"ok": True, "planted": flag_id, "remaining": remaining}

        if name == "record_user_action":
            kind = str(args.get("kind") or "").strip()
            if kind not in ACTION_LABELS:
                return {"ok": False, "error": f"unknown action kind {kind!r}"}
            if kind == "clicked_link":
                return {
                    "ok": False,
                    "error": "clicked_link is recorded by the client when the learner clicks, not by the model",
                }
            if kind in round.actions:
                return {"ok": True, "already_recorded": True, "kind": kind}
            if not action_supported(kind, user_text, otp_requested=self._otp_requested(round)):
                return {
                    "ok": False,
                    "error": "the learner's message does not support that action, so it was not recorded",
                }
            evidence = str(args.get("evidence") or "")[:160]
            round.actions[kind] = Action(kind=kind, source="model", evidence=evidence)
            return {"ok": True, "recorded": kind}

        if name == "score_round":
            round.score = self._compute(round)
            round.status = "scored"
            return {"ok": True, "weigh_in_ready": True}

        return {"ok": False, "error": f"unknown tool {name!r}"}

    @staticmethod
    def _rollback(
        round: Round,
        before_len: int,
        before_planted: set[str],
        before_actions: dict[str, Action],
        before_status: str,
        before_score: dict | None,
    ) -> None:
        del round.transcript[before_len:]
        round.planted = before_planted
        round.actions = before_actions
        round.status = before_status
        round.score = before_score
        # Drop the SDK chat so any partial tool-call turn cannot poison retries.
        round.chat = None


def _response_text(response) -> str:
    try:
        candidates = getattr(response, "candidates", None) or []
        if candidates:
            content = getattr(candidates[0], "content", None)
            parts = getattr(content, "parts", None) or []
            chunks = [
                part.text
                for part in parts
                if getattr(part, "text", None) and not getattr(part, "thought", False)
            ]
            if chunks:
                return "".join(chunks).strip()
        return (response.text or "").strip()
    except Exception:  # noqa: BLE001 - a blocked candidate has no text
        return ""
