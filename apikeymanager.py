import os
import json
import sqlite3
from datetime import datetime, timedelta
from typing import List, Dict, Optional

DB_PATH = os.path.join(os.path.dirname(__file__), "apikeys.db")

# Model quota configuration (static, can be extended)
MODEL_QUOTAS = {
    "llama-2-7b": {
        "max_requests_per_day": 10000,
        "max_requests_per_minute": 100,
        "max_tokens_per_minute": 120000,
        "max_tokens_per_day": 10000000
    },
    "llama-3-8b-instant": {
        "max_requests_per_day": 10000,
        "max_requests_per_minute": 100,
        "max_tokens_per_minute": 120000,
        "max_tokens_per_day": 10000000
    },
    "llama-3-70b-8192": {
        "max_requests_per_day": 10000,
        "max_requests_per_minute": 100,
        "max_tokens_per_minute": 120000,
        "max_tokens_per_day": 10000000
    },
    "deepseek-llm-67b": {
        "max_requests_per_day": 10000,
        "max_requests_per_minute": 100,
        "max_tokens_per_minute": 120000,
        "max_tokens_per_day": 10000000
    },
    "qwen-32b": {
        "max_requests_per_day": 10000,
        "max_requests_per_minute": 100,
        "max_tokens_per_minute": 120000,
        "max_tokens_per_day": 10000000
    },
}

def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''
        CREATE TABLE IF NOT EXISTS apikey_usage (
            apikey TEXT,
            model TEXT,
            date TEXT,
            requests_today INTEGER,
            requests_minute INTEGER,
            tokens_today INTEGER,
            tokens_minute INTEGER,
            last_minute TEXT,
            PRIMARY KEY (apikey, model, date)
        )
    ''')
    conn.commit()
    conn.close()

def update_usage(apikey: str, model: str, tokens: int):
    now = datetime.utcnow()
    date_str = now.strftime("%Y-%m-%d")
    minute_str = now.strftime("%Y-%m-%d %H:%M")
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''SELECT requests_today, requests_minute, tokens_today, tokens_minute, last_minute FROM apikey_usage WHERE apikey=? AND model=? AND date=?''', (apikey, model, date_str))
    row = c.fetchone()
    if row:
        requests_today, requests_minute, tokens_today, tokens_minute, last_minute = row
        if last_minute != minute_str:
            requests_minute = 0
            tokens_minute = 0
        requests_today += 1
        requests_minute += 1
        tokens_today += tokens
        tokens_minute += tokens
        c.execute('''UPDATE apikey_usage SET requests_today=?, requests_minute=?, tokens_today=?, tokens_minute=?, last_minute=? WHERE apikey=? AND model=? AND date=?''',
                  (requests_today, requests_minute, tokens_today, tokens_minute, minute_str, apikey, model, date_str))
    else:
        c.execute('''INSERT INTO apikey_usage (apikey, model, date, requests_today, requests_minute, tokens_today, tokens_minute, last_minute) VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
                  (apikey, model, date_str, 1, 1, tokens, tokens, minute_str))
    conn.commit()
    conn.close()

def get_usage(apikey: str, model: str) -> Dict:
    now = datetime.utcnow()
    date_str = now.strftime("%Y-%m-%d")
    minute_str = now.strftime("%Y-%m-%d %H:%M")
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''SELECT requests_today, requests_minute, tokens_today, tokens_minute, last_minute FROM apikey_usage WHERE apikey=? AND model=? AND date=?''', (apikey, model, date_str))
    row = c.fetchone()
    if row:
        requests_today, requests_minute, tokens_today, tokens_minute, last_minute = row
        # Reset per-minute if minute changed
        if last_minute != minute_str:
            requests_minute = 0
            tokens_minute = 0
            # Update DB with reset values
            c.execute('''UPDATE apikey_usage SET requests_minute=?, tokens_minute=?, last_minute=? WHERE apikey=? AND model=? AND date=?''',
                      (0, 0, minute_str, apikey, model, date_str))
            conn.commit()
        # Reset per-day if day changed (shouldn't happen due to date key, but for safety)
        if row and row[2] != 0 and date_str != row[2]:
            requests_today = 0
            tokens_today = 0
            c.execute('''UPDATE apikey_usage SET requests_today=?, tokens_today=? WHERE apikey=? AND model=? AND date=?''',
                      (0, 0, apikey, model, date_str))
            conn.commit()
        conn.close()
        return {
            "requests_today": requests_today,
            "requests_minute": requests_minute,
            "tokens_today": tokens_today,
            "tokens_minute": tokens_minute
        }
    else:
        conn.close()
        return {
            "requests_today": 0,
            "requests_minute": 0,
            "tokens_today": 0,
            "tokens_minute": 0
        }

def optimal_apikey(model: str, apikeys: List[str]) -> Optional[str]:
    """
    Decide which API key to use for a given model, based on usage and quotas.
    Returns the best key or None if all are exhausted.
    """
    init_db()
    quotas = MODEL_QUOTAS.get(model)
    if not quotas:
        return None
    best_key = None
    best_score = -1
    for key in apikeys:
        usage = get_usage(key, model)
        # Calculate remaining quota, treat 0 as unlimited
        def rem(maxval, used):
            return float('inf') if maxval == 0 else maxval - used
        rem_req_day = rem(quotas["max_requests_per_day"], usage["requests_today"])
        rem_req_min = rem(quotas["max_requests_per_minute"], usage["requests_minute"])
        rem_tok_day = rem(quotas["max_tokens_per_day"], usage["tokens_today"])
        rem_tok_min = rem(quotas["max_tokens_per_minute"], usage["tokens_minute"])
        # Score: prioritize not hitting any limit
        score = min(rem_req_day, rem_req_min, rem_tok_day, rem_tok_min)
        if score > best_score:
            best_score = score
            best_key = key
    if best_score <= 0:
        return None
    return best_key

# Optionally: add a function to reset usage (for admin/maintenance)
def reset_usage():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('DELETE FROM apikey_usage')
    conn.commit()
    conn.close()
