"""add uuidv7 function in SQL

Revision ID: 1c9ba48be8e4
Revises: 58eb7bdb93fe
Create Date: 2025-07-02 23:32:38.484499

Pigsty patch: PostgreSQL 18 provides pg_catalog.uuidv7(), so creating another
unqualified uuidv7() breaks the upstream migration's COMMENT statement. Keep
the custom function on older PostgreSQL releases and only add Dify's
uuidv7_boundary(timestamptz) helper on PostgreSQL 18+.
"""

from alembic import op
import sqlalchemy as sa


revision = "1c9ba48be8e4"
down_revision = "58eb7bdb93fe"
branch_labels = None
depends_on = None


def _is_pg(conn):
    return conn.dialect.name == "postgresql"


def _pg_version_num(conn):
    return int(conn.execute(sa.text("SHOW server_version_num")).scalar())


def upgrade():
    conn = op.get_bind()

    if not _is_pg(conn):
        return

    if _pg_version_num(conn) < 180000:
        op.execute(sa.text(r"""
/* Main function to generate a uuidv7 value with millisecond precision */
CREATE OR REPLACE FUNCTION uuidv7() RETURNS uuid
AS
$$
    -- Replace the first 48 bits of a uuidv4 with the current
    -- number of milliseconds since 1970-01-01 UTC
    -- and set the "ver" field to 7 by setting additional bits
SELECT encode(
               set_bit(
                       set_bit(
                               overlay(uuid_send(gen_random_uuid()) placing
                                       substring(int8send((extract(epoch from clock_timestamp()) * 1000)::bigint) from
                                                 3)
                                       from 1 for 6),
                               52, 1),
                       53, 1), 'hex')::uuid;
$$ LANGUAGE SQL VOLATILE PARALLEL SAFE;

COMMENT ON FUNCTION uuidv7() IS
    'Generate a uuid-v7 value with a 48-bit timestamp (millisecond precision) and 74 bits of randomness';
"""))

    op.execute(sa.text(r"""
CREATE OR REPLACE FUNCTION uuidv7_boundary(timestamptz) RETURNS uuid
AS
$$
    /* uuid fields: version=0b0111, variant=0b10 */
SELECT encode(
               overlay('\x00000000000070008000000000000000'::bytea
                       placing substring(int8send(floor(extract(epoch from $1) * 1000)::bigint) from 3)
                       from 1 for 6),
               'hex')::uuid;
$$ LANGUAGE SQL STABLE STRICT PARALLEL SAFE;

COMMENT ON FUNCTION uuidv7_boundary(timestamptz) IS
    'Generate a non-random uuidv7 with the given timestamp (first 48 bits) and all random bits to 0. As the smallest possible uuidv7 for that timestamp, it may be used as a boundary for partitions.';
"""))


def downgrade():
    conn = op.get_bind()

    if not _is_pg(conn):
        return

    op.execute(sa.text("DROP FUNCTION IF EXISTS uuidv7_boundary(timestamptz)"))
    if _pg_version_num(conn) < 180000:
        op.execute(sa.text("DROP FUNCTION IF EXISTS uuidv7()"))
