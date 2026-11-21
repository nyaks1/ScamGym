"""Shared server singletons."""

from app.config import settings
from app.engine.rounds import RoundManager
from app.engine.trainer import Trainer
from app.gemini import GeminiService

gemini = GeminiService(settings)
rounds = RoundManager(settings.round_ttl_minutes)
trainer = Trainer(gemini, rounds)
