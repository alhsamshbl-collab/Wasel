"""Additive migration for offline acknowledgements."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect

revision = "0002_offline_receipts"
down_revision = "0001_initial"
branch_labels = None
depends_on = None

def upgrade():
    bind = op.get_bind()
    inspector = inspect(bind)
    if "messages" in inspector.get_table_names():
        columns = {item["name"] for item in inspector.get_columns("messages")}
        if "cloud_purged" not in columns:
            op.add_column("messages", sa.Column("cloud_purged", sa.Boolean(), nullable=False, server_default=sa.false()))
    inspector = inspect(bind)
    if "message_receipts" not in inspector.get_table_names():
        op.create_table(
            "message_receipts",
            sa.Column("id", sa.BigInteger(), primary_key=True, autoincrement=True),
            sa.Column("message_id", sa.BigInteger(), nullable=False),
            sa.Column("user_id", sa.BigInteger(), nullable=False),
            sa.Column("saved_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.UniqueConstraint("message_id", "user_id", name="uq_message_receipt_user"),
        )
        op.create_index("ix_message_receipts_message_id", "message_receipts", ["message_id"])
        op.create_index("ix_message_receipts_user_id", "message_receipts", ["user_id"])

def downgrade():
    pass
