from __future__ import annotations

import datetime
import difflib
import json
import os
import re
import shutil
from pathlib import Path
import argparse
from contextlib import asynccontextmanager
from typing import Any, Generator, Optional

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from openai import OpenAI
from pydantic import BaseModel
from sqlalchemy import Boolean, Column, Integer, String, Text, create_engine, func, inspect, text
from sqlalchemy.orm import Session, declarative_base, sessionmaker


def load_local_env_file(path: str = ".env.local") -> None:
    env_path = Path(path)
    if not env_path.exists():
        return
    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


load_local_env_file()


def resolve_database_url() -> str:
    raw_url = (
        os.getenv("SMART_BUTLER_DB_URL")
        or os.getenv("DATABASE_URL")
        or "sqlite:///./chat_history.db"
    ).strip()
    if raw_url.startswith("postgresql://"):
        return raw_url.replace("postgresql://", "postgresql+psycopg://", 1)
    return raw_url


APP_ENV = os.getenv("SMART_BUTLER_ENV", "dev").strip().lower()
SQLALCHEMY_DATABASE_URL = resolve_database_url()
DEFAULT_MODEL = "qwen-turbo"
DEFAULT_API_BASE = "https://dashscope.aliyuncs.com/compatible-mode/v1"
LLM_API_BASE = os.getenv("DASHSCOPE_BASE_URL") or os.getenv("OPENAI_BASE_URL") or DEFAULT_API_BASE
LLM_API_KEY = os.getenv("DASHSCOPE_API_KEY") or os.getenv("OPENAI_API_KEY") or ""
INITIAL_QUOTA = 986379
ENGLISH_EXAMPLE_TARGET = 1000
CORE_STAT_KEYS = {"reflection", "study", "exercise", "english"}
DEFAULT_ALLOW_ORIGINS = "*" if APP_ENV != "prod" else ""
ALLOW_ORIGINS = [
    origin.strip()
    for origin in (os.getenv("SMART_BUTLER_ALLOW_ORIGINS") or DEFAULT_ALLOW_ORIGINS).split(",")
    if origin.strip()
]
DAILY_INSPIRATION_LIBRARY = [
    {
        "text": "The impediment to action advances action. What stands in the way becomes the way.",
        "source": "Marcus Aurelius",
    },
    {
        "text": "Easy choices, hard life. Hard choices, easy life.",
        "source": "Jerzy Gregorek",
    },
    {
        "text": "You do not rise to the level of your goals. You fall to the level of your systems.",
        "source": "James Clear",
    },
    {
        "text": "What you do every day matters more than what you do once in a while.",
        "source": "Gretchen Rubin",
    },
    {
        "text": "Do not pray for an easy life; pray for the strength to endure a difficult one.",
        "source": "Bruce Lee",
    },
    {
        "text": "Success is never owned. It is rented, and the rent is due every day.",
        "source": "Rory Vaden",
    },
    {
        "text": "志不求易者成，事不避难者进。",
        "source": "《后汉书》",
    },
    {
        "text": "千磨万击还坚劲，任尔东西南北风。",
        "source": "郑燮《竹石》",
    },
    {
        "text": "路虽远，行则将至；事虽难，做则必成。",
        "source": "《荀子》",
    },
    {
        "text": "长风破浪会有时，直挂云帆济沧海。",
        "source": "李白《行路难》",
    },
    {
        "text": "纸上得来终觉浅，绝知此事要躬行。",
        "source": "陆游《冬夜读书示子聿》",
    },
    {
        "text": "不驰于空想，不骛于虚声。",
        "source": "李大钊",
    },
    {
        "text": "所有看似波澜不惊的日复一日，终会让你看到坚持的意义。",
        "source": "改编自王尔德语意",
    },
    {
        "text": "The future depends on what you do today.",
        "source": "Mahatma Gandhi",
    },
    {
        "text": "Discipline is choosing between what you want now and what you want most.",
        "source": "Abraham Lincoln (attributed)",
    },
    {
        "text": "不积跬步，无以至千里；不积小流，无以成江海。",
        "source": "《荀子·劝学》",
    },
]

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class DBMessage(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)
    role = Column(String(50))
    content = Column(Text)
    time = Column(String(8), nullable=False, default="")


class UserSettings(Base):
    __tablename__ = "user_settings"

    id = Column(Integer, primary_key=True, index=True)
    total_quota = Column(Integer, default=INITIAL_QUOTA)
    english_mode = Column(Boolean, nullable=False, default=False)
    proactive_followup = Column(Boolean, nullable=False, default=True)
    do_not_disturb_start = Column(String(5), nullable=False, default="23:30")
    do_not_disturb_end = Column(String(5), nullable=False, default="07:00")
    bedtime_time = Column(String(5), nullable=False, default="22:30")
    freeze_tokens = Column(Integer, nullable=False, default=1)
    freeze_used_this_week = Column(Integer, nullable=False, default=0)
    freeze_week_anchor = Column(String(10), nullable=False, default="")


class TaskConfig(Base):
    __tablename__ = "task_configs"

    id = Column(Integer, primary_key=True, index=True)
    task_key = Column(String(50), unique=True, nullable=False)
    title = Column(String(100), nullable=False)
    body = Column(Text, nullable=False)
    enabled = Column(Boolean, nullable=False, default=True)
    schedule_type = Column(String(20), nullable=False)
    interval_minutes = Column(Integer, nullable=True)
    time_of_day = Column(String(5), nullable=True)
    route = Column(String(30), nullable=False, default="task")


class HabitItem(Base):
    __tablename__ = "habit_items"

    id = Column(Integer, primary_key=True, index=True)
    habit_key = Column(String(50), unique=True, nullable=False)
    title = Column(String(100), nullable=False)
    icon = Column(String(40), nullable=False, default="check_circle")
    category = Column(String(30), nullable=False, default="wellbeing")
    enabled = Column(Boolean, nullable=False, default=True)
    is_custom = Column(Boolean, nullable=False, default=False)


class UserMemory(Base):
    __tablename__ = "user_memory"

    id = Column(Integer, primary_key=True, index=True)
    memory_key = Column(String(50), nullable=False)
    memory_value = Column(Text, nullable=False)
    category = Column(String(30), nullable=False, default="profile")


class StreakStat(Base):
    __tablename__ = "streak_stats"

    id = Column(Integer, primary_key=True, index=True)
    stat_key = Column(String(50), unique=True, nullable=False)
    count = Column(Integer, nullable=False, default=0)
    last_date = Column(String(10), nullable=True)


class StatEvent(Base):
    __tablename__ = "stat_events"

    id = Column(Integer, primary_key=True, index=True)
    stat_key = Column(String(50), nullable=False)
    event_date = Column(String(10), nullable=False)
    event_time = Column(String(8), nullable=False, default="00:00:00")


class EnglishExample(Base):
    __tablename__ = "english_examples"

    id = Column(Integer, primary_key=True, index=True)
    scene = Column(String(30), nullable=False)
    text = Column(Text, nullable=False)
    source = Column(String(120), nullable=False, default="curated")


class PhraseCard(Base):
    __tablename__ = "phrase_cards"

    id = Column(Integer, primary_key=True, index=True)
    phrase = Column(Text, nullable=False)
    scene = Column(String(50), nullable=False, default="general")
    note = Column(Text, nullable=False, default="")
    created_at = Column(String(19), nullable=False, default="")


class StreakFreezeDay(Base):
    __tablename__ = "streak_freeze_days"

    id = Column(Integer, primary_key=True, index=True)
    stat_key = Column(String(50), nullable=False)
    day = Column(String(10), nullable=False)
    reason = Column(String(20), nullable=False, default="freeze")


class ChatRequest(BaseModel):
    message: str
    visible_text: Optional[str] = None


class TaskConfigPayload(BaseModel):
    task_key: str
    title: str
    body: str
    enabled: bool
    schedule_type: str
    interval_minutes: Optional[int] = None
    time_of_day: Optional[str] = None
    route: str = "task"


class UserSettingsPayload(BaseModel):
    english_mode: bool
    proactive_followup: bool
    do_not_disturb_start: str
    do_not_disturb_end: str
    bedtime_time: str


class UserMemoryPayload(BaseModel):
    memory_key: str
    memory_value: str
    category: str = "profile"


class ProgressRecordPayload(BaseModel):
    stat_key: str
    count: int = 1


class ProgressDayPayload(BaseModel):
    stat_key: str
    target_date: Optional[str] = None


class HabitPayload(BaseModel):
    habit_key: str
    title: str
    icon: str = "check_circle"
    category: str = "wellbeing"
    enabled: bool = True
    is_custom: bool = True


class PhraseCardPayload(BaseModel):
    phrase: str
    scene: str = "general"
    note: str = ""


client = OpenAI(
    api_key=LLM_API_KEY,
    base_url=LLM_API_BASE,
) if LLM_API_KEY else None


def current_time_str() -> str:
    return datetime.datetime.now().strftime("%H:%M:%S")


def current_datetime() -> datetime.datetime:
    return datetime.datetime.now()


def current_datetime_str() -> str:
    return current_datetime().strftime("%Y-%m-%d %H:%M:%S")


def today_str() -> str:
    return datetime.date.today().isoformat()


def week_anchor(day: Optional[datetime.date] = None) -> str:
    base = day or datetime.date.today()
    monday = base - datetime.timedelta(days=base.weekday())
    return monday.isoformat()


def parse_iso_date(day_text: str) -> datetime.date:
    return datetime.date.fromisoformat(day_text)


def should_use_english(text_value: str) -> bool:
    has_english = any(char.isascii() and char.isalpha() for char in text_value)
    has_chinese = any("\u4e00" <= char <= "\u9fff" for char in text_value)
    return has_english and not has_chinese


def normalize_reply_text(reply: Optional[str]) -> str:
    if not reply:
        return ""
    cleaned = reply
    cleaned = re.sub(r"```[\s\S]*?```", "", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"</?[a-zA-Z_][a-zA-Z0-9_\-]*\b[^>]*>", "", cleaned)
    cleaned = re.sub(r"`([^`]+)`", r"\1", cleaned)
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
    return cleaned.strip()


def ensure_column(table_name: str, column_name: str, ddl: str) -> None:
    inspector = inspect(engine)
    columns = {column["name"] for column in inspector.get_columns(table_name)}
    if column_name not in columns:
        with engine.begin() as conn:
            conn.execute(text(f"ALTER TABLE {table_name} ADD COLUMN {ddl}"))


def default_task_configs() -> list[dict[str, object]]:
    return [
        {
            "task_key": "hydration",
            "title": "Hydration reminder",
            "body": "Time for a short break and a glass of water.",
            "enabled": True,
            "schedule_type": "interval",
            "interval_minutes": 60,
            "time_of_day": None,
            "route": "task",
        },
        {
            "task_key": "bedtime_checkin",
            "title": "Evening check-in",
            "body": "Let's review your mood, study, exercise, and tomorrow plan.",
            "enabled": True,
            "schedule_type": "daily",
            "interval_minutes": None,
            "time_of_day": "22:30",
            "route": "review",
        },
        {
            "task_key": "vocabulary",
            "title": "Vocabulary sprint",
            "body": "Time for a quick vocabulary review. Five words is enough.",
            "enabled": False,
            "schedule_type": "daily",
            "interval_minutes": None,
            "time_of_day": "20:00",
            "route": "task",
        },
        {
            "task_key": "eye_break",
            "title": "Eye break",
            "body": "Look away from the screen for a minute and relax your eyes.",
            "enabled": False,
            "schedule_type": "interval",
            "interval_minutes": 90,
            "time_of_day": None,
            "route": "task",
        },
        {
            "task_key": "stand_up",
            "title": "Stand up",
            "body": "Stand up, stretch, and move around for two minutes.",
            "enabled": False,
            "schedule_type": "interval",
            "interval_minutes": 120,
            "time_of_day": None,
            "route": "task",
        },
        {
            "task_key": "study_review",
            "title": "Study review",
            "body": "Quick study review: what did you learn, what is still unclear, what comes next?",
            "enabled": False,
            "schedule_type": "daily",
            "interval_minutes": None,
            "time_of_day": "21:00",
            "route": "review",
        },
        {
            "task_key": "daily_inspiration",
            "title": "Daily inspiration",
            "body": "A focused life is built one day at a time.",
            "enabled": True,
            "schedule_type": "daily",
            "interval_minutes": None,
            "time_of_day": "07:40",
            "route": "task",
        },
    ]


def today_inspiration(day: Optional[datetime.date] = None) -> dict[str, str]:
    target_day = day or datetime.date.today()
    index = (target_day.toordinal() * 7 + target_day.month) % len(DAILY_INSPIRATION_LIBRARY)
    return DAILY_INSPIRATION_LIBRARY[index]


def default_habit_items() -> list[dict[str, object]]:
    return [
        {
            "habit_key": "drink_water",
            "title": "Drink Water",
            "icon": "local_drink",
            "category": "wellbeing",
            "enabled": True,
            "is_custom": False,
        },
        {
            "habit_key": "morning_stretch",
            "title": "Morning Stretch",
            "icon": "self_improvement",
            "category": "fitness",
            "enabled": True,
            "is_custom": False,
        },
        {
            "habit_key": "read_20min",
            "title": "Read 20 min",
            "icon": "menu_book",
            "category": "learning",
            "enabled": True,
            "is_custom": False,
        },
        {
            "habit_key": "walk_30min",
            "title": "Walk 30 min",
            "icon": "directions_walk",
            "category": "fitness",
            "enabled": True,
            "is_custom": False,
        },
        {
            "habit_key": "sleep_before_2330",
            "title": "Sleep Before 23:30",
            "icon": "bedtime",
            "category": "wellbeing",
            "enabled": True,
            "is_custom": False,
        },
        {
            "habit_key": "english_speaking",
            "title": "English Speaking",
            "icon": "record_voice_over",
            "category": "learning",
            "enabled": True,
            "is_custom": False,
        },
    ]


def _generate_scene_examples(
    scene: str,
    seed_sentences: list[str],
    action_phrases: list[str],
    contexts: list[str],
    closers: list[str],
    target_count: int = 200,
) -> list[str]:
    templates = [
        "Could you {action} {context} {closer}?",
        "Can we {action} {context} {closer}?",
        "I need to {action} {context} {closer}.",
        "I'd like to {action} {context} {closer}.",
        "Let's {action} {context} {closer}.",
        "Do you mind if we {action} {context} {closer}?",
    ]

    def normalize_spaces(text_value: str) -> str:
        text_value = re.sub(r"\s+", " ", text_value).strip()
        text_value = text_value.replace(" .", ".").replace(" ?", "?")
        return text_value

    generated: list[str] = []
    seen: set[str] = set()

    for sentence in seed_sentences:
        cleaned = normalize_spaces(sentence)
        lowered = cleaned.lower()
        if cleaned and lowered not in seen:
            generated.append(cleaned)
            seen.add(lowered)

    for action in action_phrases:
        for context in contexts:
            for closer in closers:
                for template in templates:
                    sentence = normalize_spaces(
                        template.format(action=action, context=context, closer=closer)
                    )
                    lowered = sentence.lower()
                    if lowered in seen:
                        continue
                    generated.append(sentence)
                    seen.add(lowered)
                    if len(generated) >= target_count:
                        return generated

    return generated[:target_count]


def default_english_examples() -> list[dict[str, str]]:
    # Curated and expanded from public English-learning references (British Council, BBC Learning English, EF English)
    # plus template-based permutations for large-sample speaking practice.
    scene_configs = {
        "daily conversation": {
            "seed": [
                "Hey, how is your day going?",
                "Do you want to grab coffee later?",
                "Could you say that one more time?",
                "I am running a little late, sorry.",
            ],
            "actions": [
                "repeat that",
                "speak a little slower",
                "keep this simple",
                "take a short break",
                "talk about this later",
                "share your thoughts",
                "help me with this sentence",
                "pick a time to meet",
                "try a different approach",
                "check in again",
            ],
            "contexts": [
                "for me",
                "with me",
                "right now",
                "after lunch",
                "this evening",
                "before we leave",
                "in a simple way",
                "when you have time",
                "for a minute",
                "today",
            ],
            "closers": ["", "please", "if possible", "when you can"],
        },
        "work": {
            "seed": [
                "Can we align on the priorities for this week?",
                "I need a bit more context before I start.",
                "I finished the draft and would love feedback.",
                "Could we schedule a quick sync tomorrow morning?",
            ],
            "actions": [
                "review this draft",
                "clarify the requirements",
                "align on priorities",
                "move this deadline",
                "share the latest update",
                "walk through the key points",
                "focus on the top risks",
                "confirm the next steps",
                "reduce the scope",
                "finalize this plan",
            ],
            "contexts": [
                "for this sprint",
                "for this task",
                "for this release",
                "before the meeting",
                "by end of day",
                "this week",
                "this afternoon",
                "with the team",
                "in the next update",
                "for better clarity",
            ],
            "closers": ["", "please", "if that works", "when you have a minute"],
        },
        "school": {
            "seed": [
                "Could you explain this part one more time?",
                "I did not catch the last sentence.",
                "I need help organizing my study plan.",
                "I am preparing for next week's quiz.",
            ],
            "actions": [
                "explain this concept",
                "check my answer",
                "review the key points",
                "practice this topic",
                "go over the homework",
                "share your class notes",
                "study together",
                "build a study plan",
                "summarize this chapter",
                "prepare for the quiz",
            ],
            "contexts": [
                "for today's lesson",
                "for this chapter",
                "before class",
                "after class",
                "for the test",
                "for tomorrow",
                "this week",
                "in simple English",
                "for ten minutes",
                "right now",
            ],
            "closers": ["", "please", "if possible", "when you are free"],
        },
        "gym": {
            "seed": [
                "Can you check my form for this exercise?",
                "I am focusing on upper body today.",
                "How many reps should I do for this?",
                "I am trying to stay consistent this month.",
            ],
            "actions": [
                "check my form",
                "show me this movement",
                "count my reps",
                "adjust this weight",
                "plan my next set",
                "track this workout",
                "focus on breathing",
                "do a short cooldown",
                "stretch first",
                "keep a steady pace",
            ],
            "contexts": [
                "for this set",
                "for this exercise",
                "before the next set",
                "after the workout",
                "for upper body day",
                "for lower body day",
                "today",
                "this week",
                "for better form",
                "for recovery",
            ],
            "closers": ["", "please", "if possible", "when you can"],
        },
        "travel": {
            "seed": [
                "Could you tell me where the station is?",
                "How long does it take to get there?",
                "I would like to check in, please.",
                "Could you recommend a local restaurant?",
            ],
            "actions": [
                "show me the way",
                "help me find this address",
                "confirm this train route",
                "book a ticket",
                "check in at the hotel",
                "recommend a local place",
                "order a local dish",
                "buy a day pass",
                "get to the airport",
                "find the nearest station",
            ],
            "contexts": [
                "from here",
                "for today",
                "for tomorrow morning",
                "before noon",
                "this afternoon",
                "with my luggage",
                "on this route",
                "near this area",
                "for this trip",
                "right now",
            ],
            "closers": ["", "please", "if possible", "when you have a moment"],
        },
        "daily errands": {
            "seed": [
                "Could you help me find this item?",
                "I just need a few things for tonight.",
                "Is there a faster way to get this done?",
                "I am stopping by before I head home.",
            ],
            "actions": [
                "find this product",
                "check the price",
                "ask for a discount",
                "compare these options",
                "pay with my card",
                "return this item",
                "pick up my order",
                "confirm the delivery time",
                "ask where this aisle is",
                "finish this quickly",
            ],
            "contexts": [
                "at the store",
                "before dinner",
                "this afternoon",
                "for my family",
                "with a small budget",
                "in a hurry",
                "for today",
                "for this weekend",
                "near my home",
                "right now",
            ],
            "closers": ["", "please", "if possible", "when you can"],
        },
        "friends and social": {
            "seed": [
                "Do you want to hang out this weekend?",
                "It has been a while since we last caught up.",
                "I am up for something chill tonight.",
                "That sounds fun, I am in.",
            ],
            "actions": [
                "make plans",
                "catch up",
                "invite friends",
                "reschedule politely",
                "share my opinion",
                "tell a short story",
                "agree naturally",
                "disagree politely",
                "ask follow-up questions",
                "keep the conversation going",
            ],
            "contexts": [
                "with close friends",
                "in casual chat",
                "on the weekend",
                "after work",
                "over dinner",
                "in a group chat",
                "without awkward silence",
                "for better connection",
                "in natural tone",
                "for small talk",
            ],
            "closers": ["", "please", "if possible", "if that works"],
        },
        "restaurant and cafe": {
            "seed": [
                "Could I get a latte with less sugar?",
                "What would you recommend here?",
                "Can we split the bill?",
                "I am allergic to peanuts.",
            ],
            "actions": [
                "order politely",
                "ask for recommendations",
                "change my order",
                "check ingredients",
                "ask for the bill",
                "reserve a table",
                "request takeaway",
                "ask for less spicy food",
                "pay separately",
                "compliment the dish",
            ],
            "contexts": [
                "at a cafe",
                "at a restaurant",
                "during lunch",
                "for dinner",
                "for takeaway",
                "with friends",
                "for a quick order",
                "with dietary needs",
                "on a busy day",
                "in polite tone",
            ],
            "closers": ["", "please", "if possible", "thanks"],
        },
        "phone calls": {
            "seed": [
                "Hi, is now a good time to talk?",
                "Sorry, the line is a bit unclear.",
                "Could you call me back in ten minutes?",
                "Let me summarize the key points quickly.",
            ],
            "actions": [
                "start a call politely",
                "ask someone to repeat",
                "reschedule the call",
                "confirm the details",
                "leave a voice message",
                "end the call naturally",
                "ask for a callback",
                "clarify the next step",
                "report a problem",
                "follow up after the call",
            ],
            "contexts": [
                "on the phone",
                "in a work call",
                "in a casual call",
                "with poor signal",
                "under time pressure",
                "for quick updates",
                "for scheduling",
                "in polite English",
                "with clear pronunciation",
                "for daily communication",
            ],
            "closers": ["", "please", "if possible", "when you are free"],
        },
        "job interview": {
            "seed": [
                "I am applying for this role because it matches my long-term goals.",
                "One strength I bring is consistent execution under pressure.",
                "A challenge I faced taught me how to communicate clearly.",
                "I would describe my working style as proactive and detail-oriented.",
            ],
            "actions": [
                "introduce myself confidently",
                "explain my strengths",
                "answer behavioral questions",
                "describe a challenge I solved",
                "talk about teamwork",
                "show leadership potential",
                "explain my career plan",
                "ask thoughtful questions",
                "clarify my responsibilities",
                "close the interview strongly",
            ],
            "contexts": [
                "in a formal interview",
                "for a graduate role",
                "for a tech position",
                "with clear structure",
                "with concise examples",
                "under time pressure",
                "with confident tone",
                "using natural transitions",
                "for better impact",
                "without sounding memorized",
            ],
            "closers": ["", "please", "if possible", "for professional tone"],
        },
        "academic discussion": {
            "seed": [
                "In my view, evidence should guide our conclusions.",
                "This topic can be analyzed from both theoretical and practical angles.",
                "A key limitation of this argument is the small sample size.",
                "It is important to define the terms before debating the issue.",
            ],
            "actions": [
                "summarize the main argument",
                "evaluate this evidence",
                "compare two perspectives",
                "challenge this assumption",
                "clarify key terms",
                "present a counterargument",
                "support my claim with data",
                "explain the methodology",
                "identify the limitation",
                "propose future research",
            ],
            "contexts": [
                "in a seminar",
                "in class discussion",
                "for an academic presentation",
                "in a research context",
                "with critical thinking",
                "using precise language",
                "with balanced tone",
                "for deeper analysis",
                "in a structured way",
                "with one concrete example",
            ],
            "closers": ["", "please", "if possible", "for clear academic tone"],
        },
        "debate and opinion": {
            "seed": [
                "I understand that point, but I see the issue differently.",
                "The long-term impact matters more than the short-term gain.",
                "We should evaluate both fairness and effectiveness.",
                "A practical compromise might work better than an extreme position.",
            ],
            "actions": [
                "state my opinion clearly",
                "disagree politely",
                "support my argument",
                "address a counterpoint",
                "give a balanced view",
                "make my point persuasive",
                "suggest a compromise",
                "reframe the question",
                "challenge weak logic",
                "conclude my position",
            ],
            "contexts": [
                "in a group discussion",
                "in a formal debate",
                "with respectful tone",
                "with strong reasoning",
                "with practical examples",
                "under time limits",
                "without emotional language",
                "for public speaking",
                "in daily conversation",
                "for clear persuasion",
            ],
            "closers": ["", "please", "if possible", "for stronger impact"],
        },
        "ielts speaking": {
            "seed": [
                "I am quite passionate about this topic because it affects my daily life.",
                "From my perspective, consistency matters more than intensity.",
                "One memorable experience I had was joining a small study group.",
                "This habit has made me more disciplined and resilient.",
            ],
            "actions": [
                "describe this experience",
                "explain my viewpoint",
                "compare two options",
                "highlight the main reason",
                "support my opinion",
                "give a concrete example",
                "organize my ideas clearly",
                "use more advanced vocabulary",
                "speak with better fluency",
                "expand this answer naturally",
            ],
            "contexts": [
                "in an IELTS speaking test",
                "for part 2",
                "for part 3",
                "with a real-life example",
                "in a coherent way",
                "with clear structure",
                "using natural linking words",
                "without memorized style",
                "in under one minute",
                "with better lexical range",
            ],
            "closers": ["", "please", "if possible", "for band 7+ style"],
        },
    }

    combined: list[dict[str, str]] = []
    for scene, cfg in scene_configs.items():
        sentences = _generate_scene_examples(
            scene=scene,
            seed_sentences=cfg["seed"],
            action_phrases=cfg["actions"],
            contexts=cfg["contexts"],
            closers=cfg["closers"],
            target_count=ENGLISH_EXAMPLE_TARGET // len(scene_configs),
        )
        combined.extend(
            [{"scene": scene, "text": sentence, "source": "curated_web_plus_templates"} for sentence in sentences]
        )

    return combined[:ENGLISH_EXAMPLE_TARGET]


def ensure_default_tasks(db: Session) -> None:
    for config in default_task_configs():
        task = db.query(TaskConfig).filter(TaskConfig.task_key == config["task_key"]).first()
        if task is None:
            db.add(TaskConfig(**config))
    db.commit()


def ensure_default_habits(db: Session) -> None:
    for item in default_habit_items():
        row = db.query(HabitItem).filter(HabitItem.habit_key == item["habit_key"]).first()
        if row is None:
            db.add(HabitItem(**item))
    db.commit()


def ensure_default_stats(db: Session) -> None:
    for stat_key in ["reflection", "study", "exercise", "english"]:
        stat = db.query(StreakStat).filter(StreakStat.stat_key == stat_key).first()
        if stat is None:
            db.add(StreakStat(stat_key=stat_key, count=0, last_date=None))
    db.commit()


def ensure_default_english_examples(db: Session) -> None:
    existing_rows = db.query(EnglishExample).all()
    seen = {(row.scene.strip().lower(), row.text.strip().lower()) for row in existing_rows}
    ielts_count = sum(1 for row in existing_rows if row.scene.strip().lower() == "ielts speaking")
    existing_scenes = {row.scene.strip().lower() for row in existing_rows}
    required_scenes = {
        "daily conversation",
        "work",
        "school",
        "gym",
        "travel",
        "daily errands",
        "friends and social",
        "restaurant and cafe",
        "phone calls",
        "job interview",
        "academic discussion",
        "debate and opinion",
        "ielts speaking",
    }
    if (
        len(seen) >= ENGLISH_EXAMPLE_TARGET
        and ielts_count >= 120
        and required_scenes.issubset(existing_scenes)
    ):
        return

    added = 0
    for item in default_english_examples():
        key = (item["scene"].strip().lower(), item["text"].strip().lower())
        if key in seen:
            continue
        db.add(EnglishExample(**item))
        seen.add(key)
        added += 1
        if len(seen) >= ENGLISH_EXAMPLE_TARGET and ielts_count >= 120:
            break
        if item["scene"].strip().lower() == "ielts speaking":
            ielts_count += 1

    if added > 0:
        db.commit()


def init_db() -> None:
    Base.metadata.create_all(bind=engine)

    ensure_column("messages", "time", "time VARCHAR(8) NOT NULL DEFAULT ''")
    ensure_column("stat_events", "event_time", "event_time VARCHAR(8) NOT NULL DEFAULT '00:00:00'")
    ensure_column("task_configs", "route", "route VARCHAR(30) NOT NULL DEFAULT 'task'")
    ensure_column("user_settings", "english_mode", "english_mode BOOLEAN NOT NULL DEFAULT 0")
    ensure_column(
        "user_settings",
        "proactive_followup",
        "proactive_followup BOOLEAN NOT NULL DEFAULT 1",
    )
    ensure_column(
        "user_settings",
        "do_not_disturb_start",
        "do_not_disturb_start VARCHAR(5) NOT NULL DEFAULT '23:30'",
    )
    ensure_column(
        "user_settings",
        "do_not_disturb_end",
        "do_not_disturb_end VARCHAR(5) NOT NULL DEFAULT '07:00'",
    )
    ensure_column(
        "user_settings",
        "bedtime_time",
        "bedtime_time VARCHAR(5) NOT NULL DEFAULT '22:30'",
    )
    ensure_column(
        "user_settings",
        "freeze_tokens",
        "freeze_tokens INTEGER NOT NULL DEFAULT 1",
    )
    ensure_column(
        "user_settings",
        "freeze_used_this_week",
        "freeze_used_this_week INTEGER NOT NULL DEFAULT 0",
    )
    ensure_column(
        "user_settings",
        "freeze_week_anchor",
        "freeze_week_anchor VARCHAR(10) NOT NULL DEFAULT ''",
    )

    with SessionLocal() as db:
        settings = db.query(UserSettings).filter(UserSettings.id == 1).first()
        if not settings:
            settings = UserSettings(
                id=1,
                total_quota=INITIAL_QUOTA,
                english_mode=False,
                proactive_followup=True,
                do_not_disturb_start="23:30",
                do_not_disturb_end="07:00",
                bedtime_time="22:30",
                freeze_tokens=1,
                freeze_used_this_week=0,
                freeze_week_anchor=week_anchor(),
            )
            db.add(settings)
            db.commit()
        elif settings.total_quota is None or settings.total_quota < 0:
            settings.total_quota = INITIAL_QUOTA
            db.commit()
        if not settings.freeze_week_anchor:
            settings.freeze_week_anchor = week_anchor()
            db.commit()

        ensure_default_tasks(db)
        ensure_default_habits(db)
        ensure_default_stats(db)
        ensure_default_english_examples(db)


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    yield


app = FastAPI(title="Smart Butler API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOW_ORIGINS or ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def memory_summary(db: Session) -> str:
    items = db.query(UserMemory).order_by(UserMemory.id.asc()).all()
    if not items:
        return "No saved user profile facts yet."
    lines = [
        f"- [{item.category}] {item.memory_key}: {item.memory_value}"
        for item in items[-20:]
    ]
    return "\n".join(lines)


def settings_summary(settings: Optional[UserSettings]) -> str:
    if settings is None:
        return "No user settings found."
    return (
        f"- English mode: {settings.english_mode}\n"
        f"- Proactive follow-up: {settings.proactive_followup}\n"
        f"- Do not disturb: {settings.do_not_disturb_start} to {settings.do_not_disturb_end}\n"
        f"- Bedtime review time: {settings.bedtime_time}\n"
        f"- Local quota: {settings.total_quota}"
    )


def build_system_prompt(settings: Optional[UserSettings], db: Session) -> str:
    return f"""
You are Smart Butler, a private AI butler for daily support, emotional companionship, English practice, and reflective coaching.

Core identity:
- Warm, observant, practical, and emotionally grounded.
- Speak like a thoughtful real companion, not a stiff assistant.
- Use conversation history and saved profile facts to remember the user.

Scene 1: Everyday conversation
- Answer normal questions naturally and directly.
- Avoid empty praise, filler, or generic motivational slogans.
- If the user shares plans or problems, help turn them into concrete next steps.

Scene 2: Emotional support
- If the user sounds low, anxious, tired, irritated, lonely, or overwhelmed, empathize first.
- Name and validate the feeling before offering advice.
- After empathy, offer at most 1-2 realistic next steps.
- Do not sound preachy or over-cheerful.

Scene 3: English practice
- If the user is speaking English, or English mode is enabled, reply fully in English first.
- Prioritize spoken, real-life English the user can use immediately (daily chat, school, commute, gym, cafe, work).
- Use natural conversational English, not textbook phrasing.
- First answer the user's actual question naturally in 2-5 sentences, like a real conversation partner.
- Gently correct major mistakes only when it helps the user.
- At most add one short "More natural way to say it" suggestion when useful.
- Do NOT output vocabulary lists, markdown bullets, or lesson-style sections unless the user explicitly asks for them.
- After the main answer, add a very short spoken vocabulary note with 1-2 useful words or phrases from your reply.
- Keep the vocabulary note practical for oral communication, and explain it briefly in simple Chinese.

Scene 4: Night reflection and coaching
- If the user is reviewing their day, or responds to a bedtime check-in, structure the answer around:
  1. Mood
  2. Study
  3. Exercise
  4. Tomorrow plan
- Keep each section concise.
- End with one realistic action for tomorrow.

Memory behavior:
- If the user shares a stable personal fact like name, goal, schedule, or preference, call the remember_user_memory tool.
- Save only facts likely to stay useful later.

Reminder behavior:
- If the user asks to be reminded, call the send_notification tool.
- If the reminder is for a clock time, compute delay_seconds from the current local time precisely.
- If the tool call has no natural reply content, add a short confirmation.

Current local time: {current_time_str()}

User settings:
{settings_summary(settings)}

Remembered user profile:
{memory_summary(db)}
"""


def update_streak(db: Session, stat_key: str) -> None:
    stat = db.query(StreakStat).filter(StreakStat.stat_key == stat_key).first()
    if stat is None:
        stat = StreakStat(stat_key=stat_key, count=0, last_date=None)
        db.add(stat)

    today = today_str()
    if stat.last_date == today:
        existing = (
            db.query(StatEvent)
            .filter(StatEvent.stat_key == stat_key, StatEvent.event_date == today)
            .first()
        )
        if existing is None:
            db.add(
                StatEvent(
                    stat_key=stat_key,
                    event_date=today,
                    event_time=current_time_str(),
                )
            )
        return

    yesterday = (datetime.date.today() - datetime.timedelta(days=1)).isoformat()
    if stat.last_date == yesterday:
        stat.count += 1
    else:
        stat.count = 1
    stat.last_date = today
    existing = (
        db.query(StatEvent)
        .filter(StatEvent.stat_key == stat_key, StatEvent.event_date == today)
        .first()
    )
    if existing is None:
        db.add(
            StatEvent(
                stat_key=stat_key,
                event_date=today,
                event_time=current_time_str(),
            )
        )


def reset_freeze_budget_if_needed(settings: UserSettings) -> None:
    current_anchor = week_anchor()
    if settings.freeze_week_anchor != current_anchor:
        settings.freeze_week_anchor = current_anchor
        settings.freeze_used_this_week = 0


def active_days_for_stat(db: Session, stat_key: str) -> set[str]:
    event_days = {
        row[0]
        for row in db.query(StatEvent.event_date)
        .filter(StatEvent.stat_key == stat_key)
        .distinct()
        .all()
        if row and row[0]
    }
    freeze_days = {
        row[0]
        for row in db.query(StreakFreezeDay.day)
        .filter(StreakFreezeDay.stat_key == stat_key, StreakFreezeDay.reason == "freeze")
        .distinct()
        .all()
        if row and row[0]
    }
    return event_days | freeze_days


def recompute_streak(db: Session, stat_key: str) -> None:
    stat = db.query(StreakStat).filter(StreakStat.stat_key == stat_key).first()
    if stat is None:
        stat = StreakStat(stat_key=stat_key, count=0, last_date=None)
        db.add(stat)

    unique_dates = sorted(active_days_for_stat(db, stat_key), reverse=True)
    if not unique_dates:
        if stat_key in CORE_STAT_KEYS:
            stat.count = 0
            stat.last_date = None
        else:
            if stat is not None:
                db.delete(stat)
        return

    stat.last_date = unique_dates[0]
    streak_count = 1
    previous = datetime.date.fromisoformat(unique_dates[0])
    for day_text in unique_dates[1:]:
        current = datetime.date.fromisoformat(day_text)
        if (previous - current).days == 1:
            streak_count += 1
            previous = current
        else:
            break
    stat.count = streak_count


def recompute_all_streaks(db: Session) -> None:
    stat_keys = {item.stat_key for item in db.query(StreakStat).all()}
    event_keys = {row[0] for row in db.query(StatEvent.stat_key).distinct().all() if row and row[0]}
    freeze_keys = {
        row[0]
        for row in db.query(StreakFreezeDay.stat_key).distinct().all()
        if row and row[0]
    }
    for key in sorted(stat_keys | event_keys | freeze_keys):
        recompute_streak(db, key)


def update_streaks_from_message(db: Session, user_msg: str, english_mode: bool) -> None:
    lowered = user_msg.lower()
    if english_mode or should_use_english(user_msg):
        update_streak(db, "english")

    if any(keyword in lowered or keyword in user_msg for keyword in ["study", "learn", "lesson", "homework", "学习", "复习", "作业"]):
        update_streak(db, "study")

    if any(keyword in lowered or keyword in user_msg for keyword in ["exercise", "workout", "run", "gym", "运动", "健身", "跑步"]):
        update_streak(db, "exercise")

    if any(
        keyword in lowered or keyword in user_msg
        for keyword in ["today", "review", "reflect", "mood", "plan", "今天", "复盘", "心情", "明天"]
    ):
        update_streak(db, "reflection")


def upsert_memory(db: Session, memory_key: str, memory_value: str, category: str) -> None:
    item = (
        db.query(UserMemory)
        .filter(UserMemory.memory_key == memory_key, UserMemory.category == category)
        .first()
    )
    if item is None:
        db.add(
            UserMemory(
                memory_key=memory_key,
                memory_value=memory_value,
                category=category,
            )
        )
    else:
        item.memory_value = memory_value


def extract_auto_memories(user_msg: str) -> list[tuple[str, str, str]]:
    text_value = user_msg.strip()
    lowered = text_value.lower()
    candidates: list[tuple[str, str, str]] = []

    patterns = [
        (r"\bmy name is ([A-Za-z][A-Za-z\s\-']{0,30})\b", "name", "profile"),
        (r"\bi am ([A-Za-z][A-Za-z\s\-']{0,30})\b", "name", "profile"),
        (r"\bcall me ([A-Za-z][A-Za-z\s\-']{0,30})\b", "name", "profile"),
        (r"我叫([^\s，。,.!?！？]{1,20})", "name", "profile"),
        (r"叫我([^\s，。,.!?！？]{1,20})", "name", "profile"),
    ]
    for pattern, key, category in patterns:
        match = re.search(pattern, text_value, flags=re.IGNORECASE)
        if match:
            value = match.group(1).strip(" .,!?:;，。！？")
            if value:
                candidates.append((key, value, category))
            break

    goal_keywords = ["goal", "plan", "target", "想要", "目标", "希望"]
    if any(keyword in lowered or keyword in text_value for keyword in goal_keywords):
        if len(text_value) <= 120:
            candidates.append(("current_goal", text_value, "goal"))

    english_keywords = ["english", "口语", "英语", "speaking"]
    if any(keyword in lowered or keyword in text_value for keyword in english_keywords):
        if len(text_value) <= 120:
            candidates.append(("english_focus", text_value, "learning"))

    seen: set[tuple[str, str]] = set()
    unique_candidates: list[tuple[str, str, str]] = []
    for key, value, category in candidates:
        token = (key, value)
        if token in seen:
            continue
        seen.add(token)
        unique_candidates.append((key, value, category))
    return unique_candidates


def infer_notification_route(title: str, content: str) -> str:
    text_blob = f"{title} {content}".lower()
    review_keywords = [
        "review",
        "check-in",
        "checkin",
        "mood",
        "study",
        "exercise",
        "tomorrow",
        "复盘",
        "回顾",
        "心情",
        "学习",
        "运动",
    ]
    return "review" if any(keyword in text_blob for keyword in review_keywords) else "task"


def normalize_example_tokens(text_value: str) -> set[str]:
    tokens = re.findall(r"[a-zA-Z']+", text_value.lower())
    stopwords = {
        "the",
        "a",
        "an",
        "to",
        "for",
        "of",
        "and",
        "or",
        "is",
        "are",
        "i",
        "you",
        "we",
        "it",
        "this",
        "that",
        "in",
        "on",
        "with",
        "my",
        "your",
        "can",
        "could",
        "would",
        "please",
    }
    return {token for token in tokens if token not in stopwords and len(token) > 2}


def normalize_sentence_for_compare(text_value: str) -> str:
    lowered = text_value.lower()
    lowered = re.sub(r"[^a-z0-9\s']", " ", lowered)
    lowered = re.sub(r"\s+", " ", lowered).strip()
    return lowered


def shingle_set(text_value: str, k: int = 3) -> set[str]:
    words = normalize_sentence_for_compare(text_value).split()
    if len(words) < k:
        return {" ".join(words)} if words else set()
    return {" ".join(words[i : i + k]) for i in range(len(words) - k + 1)}


def diversify_examples(rows: list[EnglishExample], limit: int) -> list[EnglishExample]:
    selected: list[EnglishExample] = []
    selected_tokens: list[set[str]] = []
    selected_texts: list[str] = []
    selected_shingles: list[set[str]] = []
    selected_starts: set[str] = set()

    for row in rows:
        current_tokens = normalize_example_tokens(row.text)
        current_text = normalize_sentence_for_compare(row.text)
        current_shingles = shingle_set(row.text)
        start_key = " ".join(current_text.split()[:3])
        too_similar = False

        if start_key and start_key in selected_starts:
            continue

        for previous_tokens in selected_tokens:
            if not current_tokens or not previous_tokens:
                continue
            overlap = len(current_tokens & previous_tokens)
            ratio = overlap / max(1, min(len(current_tokens), len(previous_tokens)))
            if ratio >= 0.7:
                too_similar = True
                break
        if too_similar:
            continue

        for previous_text in selected_texts:
            if difflib.SequenceMatcher(a=current_text, b=previous_text).ratio() >= 0.82:
                too_similar = True
                break
        if too_similar:
            continue

        for previous_shingles in selected_shingles:
            if not current_shingles or not previous_shingles:
                continue
            inter = len(current_shingles & previous_shingles)
            union = len(current_shingles | previous_shingles)
            if union > 0 and (inter / union) >= 0.65:
                too_similar = True
                break
        if too_similar:
            continue

        selected.append(row)
        selected_tokens.append(current_tokens)
        selected_texts.append(current_text)
        selected_shingles.append(current_shingles)
        if start_key:
            selected_starts.add(start_key)
        if len(selected) >= limit:
            return selected

    for row in rows:
        if row in selected:
            continue
        selected.append(row)
        if len(selected) >= limit:
            break
    return selected


def serialize_task(task: TaskConfig) -> dict[str, Any]:
    return {
        "task_key": task.task_key,
        "title": task.title,
        "body": task.body,
        "enabled": task.enabled,
        "schedule_type": task.schedule_type,
        "interval_minutes": task.interval_minutes,
        "time_of_day": task.time_of_day,
        "route": task.route,
    }


def serialize_habit(habit: HabitItem) -> dict[str, Any]:
    return {
        "habit_key": habit.habit_key,
        "title": habit.title,
        "icon": habit.icon,
        "category": habit.category,
        "enabled": habit.enabled,
        "is_custom": habit.is_custom,
    }


@app.get("/api/history")
def get_history(db: Session = Depends(get_db)) -> dict[str, Any]:
    records = db.query(DBMessage).order_by(DBMessage.id.asc()).all()
    settings = db.query(UserSettings).filter(UserSettings.id == 1).first()
    return {
        "status": "success",
        "history": [
            {
                "role": record.role,
                "content": record.content,
                "time": record.time or "",
            }
            for record in records
        ],
        "quota": settings.total_quota if settings else 0,
    }


@app.get("/api/tasks")
def get_tasks(db: Session = Depends(get_db)) -> dict[str, Any]:
    tasks = db.query(TaskConfig).order_by(TaskConfig.id.asc()).all()
    return {"status": "success", "tasks": [serialize_task(task) for task in tasks]}


@app.get("/api/inspiration/today")
def get_today_inspiration() -> dict[str, Any]:
    quote = today_inspiration()
    return {
        "status": "success",
        "date": today_str(),
        "title": "Daily inspiration",
        "body": f"{quote['text']} —— {quote['source']}",
        "text": quote["text"],
        "source": quote["source"],
    }


@app.post("/api/tasks")
def upsert_task(payload: TaskConfigPayload, db: Session = Depends(get_db)) -> dict[str, str]:
    task = db.query(TaskConfig).filter(TaskConfig.task_key == payload.task_key).first()
    if task is None:
        task = TaskConfig(task_key=payload.task_key)
        db.add(task)

    task.title = payload.title
    task.body = payload.body
    task.enabled = payload.enabled
    task.schedule_type = payload.schedule_type
    task.interval_minutes = payload.interval_minutes
    task.time_of_day = payload.time_of_day
    task.route = payload.route
    db.commit()
    return {"status": "success"}


@app.delete("/api/tasks/{task_key}")
def delete_task(task_key: str, db: Session = Depends(get_db)) -> dict[str, str]:
    task = db.query(TaskConfig).filter(TaskConfig.task_key == task_key).first()
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    db.delete(task)
    db.commit()
    return {"status": "success"}


@app.get("/api/habits")
def get_habits(db: Session = Depends(get_db)) -> dict[str, Any]:
    habits = db.query(HabitItem).order_by(HabitItem.id.asc()).all()
    return {
        "status": "success",
        "habits": [serialize_habit(item) for item in habits],
    }


@app.post("/api/habits")
def upsert_habit(payload: HabitPayload, db: Session = Depends(get_db)) -> dict[str, str]:
    habit_key = payload.habit_key.strip().lower()
    title = payload.title.strip()
    if not habit_key or not title:
        raise HTTPException(status_code=400, detail="habit_key and title are required")

    row = db.query(HabitItem).filter(HabitItem.habit_key == habit_key).first()
    if row is None:
        row = HabitItem(habit_key=habit_key)
        db.add(row)

    row.title = title
    row.icon = payload.icon.strip() or "check_circle"
    row.category = payload.category.strip() or "wellbeing"
    row.enabled = payload.enabled
    row.is_custom = payload.is_custom
    db.commit()
    return {"status": "success"}


@app.delete("/api/habits/{habit_key}")
def delete_habit(habit_key: str, db: Session = Depends(get_db)) -> dict[str, str]:
    row = db.query(HabitItem).filter(HabitItem.habit_key == habit_key).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Habit not found")
    db.delete(row)
    db.commit()
    return {"status": "success"}


@app.post("/api/habits/{habit_key}/checkin")
def checkin_habit(habit_key: str, db: Session = Depends(get_db)) -> dict[str, Any]:
    row = db.query(HabitItem).filter(HabitItem.habit_key == habit_key).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Habit not found")

    now_dt = current_datetime()
    now_time = now_dt.strftime("%H:%M:%S")
    day = today_str()

    latest = (
        db.query(StatEvent)
        .filter(StatEvent.stat_key == habit_key, StatEvent.event_date == day)
        .order_by(StatEvent.id.desc())
        .first()
    )
    if latest is not None:
        try:
            latest_dt = datetime.datetime.strptime(
                f"{latest.event_date} {latest.event_time}",
                "%Y-%m-%d %H:%M:%S",
            )
            if (now_dt - latest_dt).total_seconds() <= 5:
                return get_stats(db)
        except Exception:
            if latest.event_time == now_time:
                return get_stats(db)

    db.add(StatEvent(stat_key=habit_key, event_date=day, event_time=now_time))
    db.flush()
    recompute_streak(db, habit_key)
    db.commit()
    return get_stats(db)


@app.get("/api/settings")
def get_settings(db: Session = Depends(get_db)) -> dict[str, Any]:
    settings = db.query(UserSettings).filter(UserSettings.id == 1).first()
    if settings is None:
        raise HTTPException(status_code=404, detail="Settings not found")
    reset_freeze_budget_if_needed(settings)
    db.commit()
    return {
        "status": "success",
        "settings": {
            "english_mode": settings.english_mode,
            "proactive_followup": settings.proactive_followup,
            "do_not_disturb_start": settings.do_not_disturb_start,
            "do_not_disturb_end": settings.do_not_disturb_end,
            "bedtime_time": settings.bedtime_time,
            "freeze_tokens": settings.freeze_tokens,
            "freeze_used_this_week": settings.freeze_used_this_week,
            "freeze_week_anchor": settings.freeze_week_anchor,
        },
    }


@app.post("/api/settings")
def update_settings(
    payload: UserSettingsPayload,
    db: Session = Depends(get_db),
) -> dict[str, str]:
    settings = db.query(UserSettings).filter(UserSettings.id == 1).first()
    if settings is None:
        settings = UserSettings(id=1, total_quota=INITIAL_QUOTA)
        db.add(settings)

    settings.english_mode = payload.english_mode
    settings.proactive_followup = payload.proactive_followup
    settings.do_not_disturb_start = payload.do_not_disturb_start
    settings.do_not_disturb_end = payload.do_not_disturb_end
    settings.bedtime_time = payload.bedtime_time
    reset_freeze_budget_if_needed(settings)

    bedtime_task = db.query(TaskConfig).filter(TaskConfig.task_key == "bedtime_checkin").first()
    if bedtime_task is not None:
        bedtime_task.time_of_day = payload.bedtime_time

    db.commit()
    return {"status": "success"}


@app.get("/api/profile")
def get_profile(db: Session = Depends(get_db)) -> dict[str, Any]:
    items = db.query(UserMemory).order_by(UserMemory.id.asc()).all()
    return {
        "status": "success",
        "memories": [
            {
                "id": item.id,
                "memory_key": item.memory_key,
                "memory_value": item.memory_value,
                "category": item.category,
            }
            for item in items
        ],
    }


@app.post("/api/profile")
def upsert_profile(
    payload: UserMemoryPayload,
    db: Session = Depends(get_db),
) -> dict[str, str]:
    upsert_memory(db, payload.memory_key, payload.memory_value, payload.category)
    db.commit()
    return {"status": "success"}


@app.delete("/api/profile/{memory_id}")
def delete_profile(memory_id: int, db: Session = Depends(get_db)) -> dict[str, str]:
    item = db.query(UserMemory).filter(UserMemory.id == memory_id).first()
    if item is None:
        raise HTTPException(status_code=404, detail="Memory not found")
    db.delete(item)
    db.commit()
    return {"status": "success"}


@app.get("/api/english/examples")
def get_english_examples(
    scene: str = "daily conversation",
    limit: int = 5,
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    safe_limit = max(1, min(limit, 20))
    sample_size = safe_limit * 30
    normalized_scene = scene.strip().lower()

    if normalized_scene in {"mixed", "all"}:
        rows = db.query(EnglishExample).order_by(func.random()).limit(sample_size).all()
    else:
        rows = (
            db.query(EnglishExample)
            .filter(func.lower(EnglishExample.scene) == normalized_scene)
            .order_by(func.random())
            .limit(sample_size)
            .all()
        )
    if not rows:
        rows = db.query(EnglishExample).order_by(func.random()).limit(sample_size).all()

    diversified = diversify_examples(rows, safe_limit)
    if len(diversified) < safe_limit:
        fallback_rows = db.query(EnglishExample).order_by(func.random()).limit(sample_size).all()
        diversified = diversify_examples([*diversified, *fallback_rows], safe_limit)
    return {
        "status": "success",
        "scene": scene,
        "examples": [
            {"id": row.id, "scene": row.scene, "text": row.text, "source": row.source}
            for row in diversified
        ],
    }


@app.get("/api/phrase_cards")
def get_phrase_cards(db: Session = Depends(get_db)) -> dict[str, Any]:
    rows = db.query(PhraseCard).order_by(PhraseCard.id.desc()).all()
    return {
        "status": "success",
        "cards": [
            {
                "id": row.id,
                "phrase": row.phrase,
                "scene": row.scene,
                "note": row.note,
                "created_at": row.created_at,
            }
            for row in rows
        ],
    }


@app.post("/api/phrase_cards")
def create_phrase_card(
    payload: PhraseCardPayload,
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    phrase = payload.phrase.strip()
    if not phrase:
        raise HTTPException(status_code=400, detail="phrase is required")
    scene = payload.scene.strip() or "general"
    note = payload.note.strip()

    existing = (
        db.query(PhraseCard)
        .filter(
            func.lower(PhraseCard.phrase) == phrase.lower(),
            func.lower(PhraseCard.scene) == scene.lower(),
        )
        .first()
    )
    if existing is not None:
        if note:
            existing.note = note
        db.commit()
        return {"status": "success", "id": existing.id, "deduplicated": True}

    card = PhraseCard(
        phrase=phrase,
        scene=scene,
        note=note,
        created_at=current_datetime_str(),
    )
    db.add(card)
    db.commit()
    return {"status": "success", "id": card.id, "deduplicated": False}


@app.delete("/api/phrase_cards/{card_id}")
def delete_phrase_card(card_id: int, db: Session = Depends(get_db)) -> dict[str, str]:
    row = db.query(PhraseCard).filter(PhraseCard.id == card_id).first()
    if row is None:
        raise HTTPException(status_code=404, detail="Phrase card not found")
    db.delete(row)
    db.commit()
    return {"status": "success"}


@app.get("/api/stats")
def get_stats(db: Session = Depends(get_db)) -> dict[str, Any]:
    recompute_all_streaks(db)
    settings = db.query(UserSettings).filter(UserSettings.id == 1).first()
    if settings is not None:
        reset_freeze_budget_if_needed(settings)
    db.commit()
    stats = db.query(StreakStat).order_by(StreakStat.id.asc()).all()
    today = today_str()
    active_today = 0
    longest_streak = 0
    total_streak_days = 0
    for stat in stats:
        total_streak_days += stat.count
        longest_streak = max(longest_streak, stat.count)
        if stat.last_date == today:
            active_today += 1

    daily_activity: list[dict[str, Any]] = []
    for day_offset in range(6, -1, -1):
        day = (datetime.date.today() - datetime.timedelta(days=day_offset)).isoformat()
        event_count = (
            db.query(StatEvent)
            .filter(StatEvent.event_date == day)
            .count()
        )
        daily_activity.append({"date": day, "events": event_count})

    consistency_score = min(100, active_today * 25 + min(longest_streak, 20))
    total_events = db.query(StatEvent).count()

    def badge_state(code: str, title: str, unlocked: bool, progress: int) -> dict[str, Any]:
        return {
            "code": code,
            "title": title,
            "unlocked": unlocked,
            "progress": progress,
        }

    badges = [
        badge_state("streak_3", "3-day spark", longest_streak >= 3, min(longest_streak, 3)),
        badge_state("streak_7", "7-day rhythm", longest_streak >= 7, min(longest_streak, 7)),
        badge_state("streak_30", "30-day engine", longest_streak >= 30, min(longest_streak, 30)),
        badge_state("events_50", "50 check-ins", total_events >= 50, min(total_events, 50)),
        badge_state("events_200", "200 check-ins", total_events >= 200, min(total_events, 200)),
    ]

    heatmap: list[dict[str, Any]] = []
    max_heat = 1
    for day_offset in range(27, -1, -1):
        day = (datetime.date.today() - datetime.timedelta(days=day_offset)).isoformat()
        count_value = (
            db.query(StatEvent)
            .filter(StatEvent.event_date == day)
            .count()
        )
        max_heat = max(max_heat, count_value)
        heatmap.append({"date": day, "count": count_value})
    for cell in heatmap:
        ratio = cell["count"] / max_heat
        if cell["count"] == 0:
            level = 0
        elif ratio <= 0.25:
            level = 1
        elif ratio <= 0.5:
            level = 2
        elif ratio <= 0.75:
            level = 3
        else:
            level = 4
        cell["level"] = level

    monday = parse_iso_date(week_anchor())
    week_days = [(monday + datetime.timedelta(days=i)).isoformat() for i in range(7)]
    active_days_in_week = 0
    for day in week_days:
        has_event = (
            db.query(StatEvent.id)
            .filter(StatEvent.event_date == day)
            .first()
            is not None
        )
        if has_event:
            active_days_in_week += 1
    week_by_stat = []
    for row in db.query(StatEvent.stat_key, func.count(StatEvent.id)).filter(
        StatEvent.event_date >= week_days[0],
        StatEvent.event_date <= week_days[-1],
    ).group_by(StatEvent.stat_key).all():
        week_by_stat.append({"stat_key": row[0], "count": int(row[1])})

    return {
        "status": "success",
        "stats": [
            {
                "stat_key": stat.stat_key,
                "count": stat.count,
                "last_date": stat.last_date,
            }
            for stat in stats
        ],
        "summary": {
            "today_active_count": active_today,
            "longest_streak": longest_streak,
            "total_streak_days": total_streak_days,
            "consistency_score": consistency_score,
            "total_events": total_events,
        },
        "freeze": {
            "tokens": settings.freeze_tokens if settings else 1,
            "used_this_week": settings.freeze_used_this_week if settings else 0,
            "remaining_this_week": max(
                0,
                (settings.freeze_tokens - settings.freeze_used_this_week) if settings else 1,
            ),
            "week_anchor": settings.freeze_week_anchor if settings else week_anchor(),
        },
        "badges": badges,
        "heatmap": heatmap,
        "week_report": {
            "week_start": week_days[0],
            "week_end": week_days[-1],
            "active_days": active_days_in_week,
            "completion_rate": int((active_days_in_week / 7) * 100),
            "by_stat": week_by_stat,
        },
        "daily_activity": daily_activity,
        "events": [
            {
                "id": item.id,
                "stat_key": item.stat_key,
                "event_date": item.event_date,
                "event_time": item.event_time,
            }
            for item in db.query(StatEvent).order_by(StatEvent.id.desc()).limit(60).all()
        ],
    }


@app.post("/api/stats/record")
def record_progress(
    payload: ProgressRecordPayload,
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    stat_key = payload.stat_key.strip().lower()
    if not stat_key:
        raise HTTPException(status_code=400, detail="stat_key is required")

    count = max(1, min(payload.count, 20))
    day = today_str()
    now_dt = current_datetime()
    now_time = now_dt.strftime("%H:%M:%S")
    if count == 1:
        latest = (
            db.query(StatEvent)
            .filter(StatEvent.stat_key == stat_key, StatEvent.event_date == day)
            .order_by(StatEvent.id.desc())
            .first()
        )
        if latest is not None:
            try:
                latest_dt = datetime.datetime.strptime(
                    f"{latest.event_date} {latest.event_time}",
                    "%Y-%m-%d %H:%M:%S",
                )
                if (now_dt - latest_dt).total_seconds() <= 5:
                    return get_stats(db)
            except Exception:
                if latest.event_time == now_time:
                    return get_stats(db)
        db.add(StatEvent(stat_key=stat_key, event_date=day, event_time=now_time))
    else:
        for _ in range(count):
            db.add(StatEvent(stat_key=stat_key, event_date=day, event_time=now_time))

    # Ensure pending inserts are visible before streak recomputation.
    db.flush()
    recompute_streak(db, stat_key)
    db.commit()
    return get_stats(db)


@app.post("/api/stats/freeze")
def freeze_progress_day(
    payload: ProgressDayPayload,
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    stat_key = payload.stat_key.strip().lower()
    if not stat_key:
        raise HTTPException(status_code=400, detail="stat_key is required")

    settings = db.query(UserSettings).filter(UserSettings.id == 1).first()
    if settings is None:
        raise HTTPException(status_code=400, detail="Settings not found")
    reset_freeze_budget_if_needed(settings)
    if settings.freeze_used_this_week >= settings.freeze_tokens:
        raise HTTPException(status_code=400, detail="No freeze tokens left this week")

    target = payload.target_date or (
        datetime.date.today() - datetime.timedelta(days=1)
    ).isoformat()
    try:
        target_day = parse_iso_date(target)
    except Exception:
        raise HTTPException(status_code=400, detail="target_date must be YYYY-MM-DD")

    if target_day > datetime.date.today():
        raise HTTPException(status_code=400, detail="Cannot freeze a future day")
    if (datetime.date.today() - target_day).days > 2:
        raise HTTPException(status_code=400, detail="Freeze only supports recent missed days")

    event_exists = (
        db.query(StatEvent.id)
        .filter(StatEvent.stat_key == stat_key, StatEvent.event_date == target)
        .first()
        is not None
    )
    if event_exists:
        return get_stats(db)

    freeze_exists = (
        db.query(StreakFreezeDay.id)
        .filter(
            StreakFreezeDay.stat_key == stat_key,
            StreakFreezeDay.day == target,
            StreakFreezeDay.reason == "freeze",
        )
        .first()
        is not None
    )
    if freeze_exists:
        return get_stats(db)

    db.add(StreakFreezeDay(stat_key=stat_key, day=target, reason="freeze"))
    settings.freeze_used_this_week += 1
    recompute_streak(db, stat_key)
    db.commit()
    return get_stats(db)


@app.post("/api/stats/makeup")
def makeup_progress_day(
    payload: ProgressDayPayload,
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    stat_key = payload.stat_key.strip().lower()
    if not stat_key:
        raise HTTPException(status_code=400, detail="stat_key is required")

    target = payload.target_date or (
        datetime.date.today() - datetime.timedelta(days=1)
    ).isoformat()
    try:
        target_day = parse_iso_date(target)
    except Exception:
        raise HTTPException(status_code=400, detail="target_date must be YYYY-MM-DD")

    today = datetime.date.today()
    if target_day > today:
        raise HTTPException(status_code=400, detail="Cannot make up a future day")
    if (today - target_day).days > 1:
        raise HTTPException(status_code=400, detail="Make-up window is within 24h")

    event_exists = (
        db.query(StatEvent.id)
        .filter(StatEvent.stat_key == stat_key, StatEvent.event_date == target)
        .first()
        is not None
    )
    if event_exists:
        return get_stats(db)

    db.add(StatEvent(stat_key=stat_key, event_date=target, event_time=current_time_str()))
    db.add(StreakFreezeDay(stat_key=stat_key, day=target, reason="makeup"))
    recompute_streak(db, stat_key)
    db.commit()
    return get_stats(db)


def _delete_progress_event_impl(event_id: int, db: Session) -> dict[str, Any]:
    item = db.query(StatEvent).filter(StatEvent.id == event_id).first()
    if item is None:
        # Idempotent delete: if already gone, return latest stats instead of failing.
        return get_stats(db)
    stat_key = item.stat_key
    db.delete(item)
    recompute_streak(db, stat_key)
    db.commit()
    return get_stats(db)


@app.delete("/api/stats/events/{event_id}")
def delete_progress_event(event_id: int, db: Session = Depends(get_db)) -> dict[str, Any]:
    return _delete_progress_event_impl(event_id, db)


@app.delete("/api/stats/event/{event_id}")
def delete_progress_event_compat(event_id: int, db: Session = Depends(get_db)) -> dict[str, Any]:
    return _delete_progress_event_impl(event_id, db)


@app.delete("/api/progress/events/{event_id}")
def delete_progress_event_compat_v2(event_id: int, db: Session = Depends(get_db)) -> dict[str, Any]:
    return _delete_progress_event_impl(event_id, db)


@app.post("/api/chat")
def chat_with_butler(request: ChatRequest, db: Session = Depends(get_db)) -> dict[str, Any]:
    user_msg = request.message.strip()
    user_visible_text = (request.visible_text or "").strip()

    settings = db.query(UserSettings).filter(UserSettings.id == 1).first()
    current_quota = settings.total_quota if settings else 0

    if not user_msg:
        return {
            "status": "error",
            "reply": "Message cannot be empty.",
            "action": None,
            "quota": current_quota,
        }

    if current_quota <= 0:
        return {
            "status": "error",
            "reply": "Warning: your cloud model quota is exhausted. Smart Butler is temporarily offline.",
            "action": None,
            "quota": current_quota,
        }

    if client is None:
        return {
            "status": "error",
            "reply": (
                "Model key is not configured. Set DASHSCOPE_API_KEY or OPENAI_API_KEY "
                "on the server and restart."
            ),
            "action": None,
            "quota": current_quota,
        }

    for memory_key, memory_value, category in extract_auto_memories(user_msg):
        upsert_memory(db, memory_key, memory_value, category)

    messages = [
        {"role": "system", "content": build_system_prompt(settings, db)},
    ]
    history_records = db.query(DBMessage).order_by(DBMessage.id.asc()).all()[-10:]
    for record in history_records:
        messages.append({"role": record.role, "content": record.content})
    messages.append({"role": "user", "content": user_msg})

    try:
        tools = [
            {
                "type": "function",
                "function": {
                    "name": "send_notification",
                    "description": "Create a reminder notification for the user.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "title": {"type": "string"},
                            "content": {"type": "string"},
                            "delay_seconds": {"type": "integer"},
                        },
                        "required": ["title", "content", "delay_seconds"],
                    },
                },
            },
            {
                "type": "function",
                "function": {
                    "name": "remember_user_memory",
                    "description": "Save a stable personal fact about the user for future conversations.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "memory_key": {"type": "string"},
                            "memory_value": {"type": "string"},
                            "category": {"type": "string"},
                        },
                        "required": ["memory_key", "memory_value", "category"],
                    },
                },
            },
        ]

        response = client.chat.completions.create(
            model=os.getenv("SMART_BUTLER_MODEL") or DEFAULT_MODEL,
            messages=messages,
            tools=tools,
            temperature=0.7,
        )

        response_msg = response.choices[0].message
        reply_content = normalize_reply_text(response_msg.content)
        action_data = None

        if response_msg.tool_calls:
            for tool_call in response_msg.tool_calls:
                if tool_call.function.name == "send_notification":
                    args = json.loads(tool_call.function.arguments)
                    title = args["title"]
                    content = args["content"]
                    action_data = {
                        "type": "notify",
                        "title": title,
                        "content": content,
                        "delay_seconds": int(args["delay_seconds"]),
                        "route": infer_notification_route(title, content),
                    }
                elif tool_call.function.name == "remember_user_memory":
                    args = json.loads(tool_call.function.arguments)
                    upsert_memory(
                        db,
                        args["memory_key"],
                        args["memory_value"],
                        args["category"],
                    )

            if not reply_content and action_data is not None:
                if should_use_english(user_msg) or (settings and settings.english_mode):
                    reply_content = (
                        f"Got it! I've set a reminder for you in {action_data['delay_seconds']} seconds."
                    )
                else:
                    reply_content = (
                        f"好的，我已经帮你设置了提醒！将在 {action_data['delay_seconds']} 秒后通知你。"
                    )

        if not reply_content:
            reply_content = "I'm here." if should_use_english(user_msg) else "我在。"

        try:
            used_tokens = response.usage.total_tokens
        except Exception:
            used_tokens = 50

        user_time = current_time_str()
        assistant_time = current_time_str()
        db.add(DBMessage(role="user", content=user_visible_text or user_msg, time=user_time))
        db.add(DBMessage(role="assistant", content=reply_content, time=assistant_time))

        if settings:
            settings.total_quota = max(0, settings.total_quota - used_tokens)
            update_streaks_from_message(db, user_msg, settings.english_mode)

        db.commit()

        return {
            "status": "success",
            "reply": reply_content,
            "action": action_data,
            "quota": settings.total_quota if settings else max(0, current_quota - used_tokens),
        }

    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


def backup_databases(base_dir: str = ".") -> list[str]:
    root = Path(base_dir).resolve()
    backup_dir = root / "backups"
    backup_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    created: list[str] = []
    for db_name in ("chat_history.db", "smart_butler.db"):
        src = root / db_name
        if not src.exists():
            continue
        dest = backup_dir / f"{db_name}.{timestamp}.bak"
        shutil.copy2(src, dest)
        created.append(str(dest))
    return created


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Smart Butler backend helper")
    parser.add_argument(
        "mode",
        nargs="?",
        default="dev",
        choices=["dev", "prod", "backup"],
        help="Run mode: dev/prod/backup",
    )
    parser.add_argument("--port", type=int, default=int(os.getenv("PORT", "8000")))
    parser.add_argument(
        "--allow-origins",
        default=os.getenv("SMART_BUTLER_ALLOW_ORIGINS", "*"),
        help="Comma-separated CORS origins for prod mode",
    )
    args = parser.parse_args()

    if args.mode == "backup":
        outputs = backup_databases(".")
        if not outputs:
            print("No database files found to back up.")
        else:
            for item in outputs:
                print(f"Backup created: {item}")
        raise SystemExit(0)

    key = os.getenv("DASHSCOPE_API_KEY") or os.getenv("OPENAI_API_KEY")
    if not key:
        raise SystemExit(
            "Missing model key. Set DASHSCOPE_API_KEY (or OPENAI_API_KEY) before starting."
        )

    os.environ["SMART_BUTLER_ENV"] = args.mode
    if args.mode == "prod":
        os.environ["SMART_BUTLER_ALLOW_ORIGINS"] = args.allow_origins

    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=args.port,
        reload=(args.mode == "dev"),
    )
