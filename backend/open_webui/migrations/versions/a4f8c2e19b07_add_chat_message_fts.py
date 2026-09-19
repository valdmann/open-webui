"""Add chat_message_fts FTS5 index for chat search

Revision ID: a4f8c2e19b07
Revises: d4c1a8e37b62
Create Date: 2026-09-18 20:40:00.000000

Chat search used to scan every chat_message row per search term
(INSTR over json_extract of the content column) and re-scan for the
phrase in the ORDER BY clause. This adds a standalone FTS5 trigram
index over the same text, kept in sync by triggers, so matching
becomes an indexed lookup. The legacy scan stays as fallback
(terms shorter than three characters cannot use a trigram index,
and deployments with the FTS feature disabled use it unchanged).
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from open_webui.migrations.util import get_existing_tables

revision: str = 'a4f8c2e19b07'
down_revision: Union[str, None] = 'd4c1a8e37b62'
branch_labels: Union[str, None, Sequence[str]] = None
depends_on: Union[str, Sequence[str], None] = None

FTS_TABLE = 'chat_message_fts'

# The indexed text mirrors what the legacy search scanned:
# json_extract(content, '$') — the raw message text for string
# content, the serialized JSON for block content. json_valid guards
# against malformed values: json_extract raises on non-JSON input,
# which would otherwise break message writes (triggers run in the
# writer's transaction). ``col`` must be a qualified column reference
# (``NEW.content`` / ``OLD.content`` inside triggers, bare ``content``
# in the backfill).
def _body_expr(col: str) -> str:
    return f"CASE WHEN json_valid({col}) THEN json_extract({col}, '$') ELSE {col} END"


TRIGGERS = (
    f"""
    CREATE TRIGGER IF NOT EXISTS chat_message_fts_ai
    AFTER INSERT ON chat_message
    BEGIN
        INSERT INTO {FTS_TABLE}(rowid, chat_id, user_id, body)
        VALUES (NEW.rowid, NEW.chat_id, NEW.user_id, {_body_expr('NEW.content')});
    END
    """,
    f"""
    CREATE TRIGGER IF NOT EXISTS chat_message_fts_au
    AFTER UPDATE OF content, user_id, chat_id ON chat_message
    BEGIN
        DELETE FROM {FTS_TABLE} WHERE rowid = OLD.rowid;
        INSERT INTO {FTS_TABLE}(rowid, chat_id, user_id, body)
        VALUES (NEW.rowid, NEW.chat_id, NEW.user_id, {_body_expr('NEW.content')});
    END
    """,
    f"""
    CREATE TRIGGER IF NOT EXISTS chat_message_fts_ad
    AFTER DELETE ON chat_message
    BEGIN
        DELETE FROM {FTS_TABLE} WHERE rowid = OLD.rowid;
    END
    """,
)


def upgrade() -> None:
    if 'chat_message' not in set(get_existing_tables()):
        return

    # FTS5 is a SQLite feature; other dialects keep the legacy scan.
    if op.get_context().dialect.name != 'sqlite':
        return

    conn = op.get_bind()

    conn.execute(
        sa.text(
            f"""
            CREATE VIRTUAL TABLE IF NOT EXISTS {FTS_TABLE} USING fts5(
                chat_id UNINDEXED,
                user_id UNINDEXED,
                body,
                tokenize='trigram'
            )
            """
        )
    )

    for trigger_sql in TRIGGERS:
        conn.execute(sa.text(trigger_sql))

    # Backfill once; the triggers keep the index in sync from then on.
    existing = conn.execute(sa.text(f'SELECT COUNT(*) FROM {FTS_TABLE}')).scalar()
    if not existing:
        conn.execute(
            sa.text(
                f"""
                INSERT INTO {FTS_TABLE}(rowid, chat_id, user_id, body)
                SELECT rowid, chat_id, user_id, {_body_expr('content')}
                FROM chat_message
                WHERE content IS NOT NULL
                """
            )
        )
    # Safety net: drop index rows whose message no longer exists.
    conn.execute(sa.text(f'DELETE FROM {FTS_TABLE} WHERE rowid NOT IN (SELECT rowid FROM chat_message)'))

    # Covering index so the search query can filter and order chats without
    # fetching the multi-megabyte chat.chat JSON blob per row. On a
    # production instance (961 chats, ~1.9 MB average row) this took the
    # main search query from ~750 ms to ~10 ms.
    op.create_index(
        'chat_search_idx',
        'chat',
        ['user_id', 'archived', sa.text('updated_at DESC'), 'id', 'title', 'meta', 'created_at', 'last_read_at', 'pinned', 'share_id', 'folder_id'],
    )


def downgrade() -> None:
    if op.get_context().dialect.name != 'sqlite':
        return

    conn = op.get_bind()
    op.drop_index('chat_search_idx', table_name='chat')
    for name in ('chat_message_fts_ad', 'chat_message_fts_au', 'chat_message_fts_ai'):
        conn.execute(sa.text(f'DROP TRIGGER IF EXISTS {name}'))
    conn.execute(sa.text(f'DROP TABLE IF EXISTS {FTS_TABLE}'))
