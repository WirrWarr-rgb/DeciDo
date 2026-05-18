"""Add new sessions module

Revision ID: 3684d0e21e8a
Revises: 0a4ad82718d9
Create Date: 2026-04-26
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '3684d0e21e8a'
down_revision = '0a4ad82718d9'
branch_labels = None
depends_on = None

def upgrade():
    # 1. Сначала создаём sessions (она не ссылается на session_lists через FK при создании)
    op.create_table('sessions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('owner_id', sa.Integer(), nullable=False),
        sa.Column('current_list_id', sa.Integer(), nullable=True),
        sa.Column('mode', sa.Enum('RANDOM', 'RANKING', name='sessionmode'), nullable=False),
        sa.Column('status', sa.Enum('WAITING', 'EDITING', 'READY', 'VOTING', 'RESULTS', 'CLOSED', name='sessionstatus'), nullable=False),
        sa.Column('list_locked', sa.Boolean(), nullable=True),
        sa.Column('voting_duration', sa.Integer(), nullable=True),
        sa.Column('countdown_ends_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('started_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('voting_ends_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('closed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('closed_by', sa.Integer(), nullable=True),
        sa.Column('results_json', sa.JSON(), nullable=True),
        sa.ForeignKeyConstraint(['closed_by'], ['users.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['owner_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_sessions_id', 'sessions', ['id'])

    # 2. Теперь session_lists (ссылается на sessions)
    op.create_table('session_lists',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('session_id', sa.Integer(), nullable=False),
        sa.Column('original_list_id', sa.Integer(), nullable=True),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['original_list_id'], ['lists.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['session_id'], ['sessions.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_session_lists_id', 'session_lists', ['id'])

    # 3. Добавляем внешний ключ current_list_id -> session_lists.id
    op.create_foreign_key('fk_sessions_current_list', 'sessions', 'session_lists', ['current_list_id'], ['id'], ondelete='SET NULL')

    # 4. session_list_items
    op.create_table('session_list_items',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('session_list_id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(200), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('image_url', sa.String(500), nullable=True),
        sa.Column('order_index', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Integer(), nullable=True),
        sa.Column('edited_by', sa.Integer(), nullable=True),
        sa.Column('edited_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['created_by'], ['users.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['edited_by'], ['users.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['session_list_id'], ['session_lists.id'],


ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_session_list_items_id', 'session_list_items', ['id'])

    # 5. session_participants
    op.create_table('session_participants',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('session_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('status', sa.Enum('INVITED', 'ACCEPTED', 'DECLINED', 'LEFT', 'KICKED', name='participantstatus'), nullable=False),
        sa.Column('is_ready', sa.Boolean(), nullable=True),
        sa.Column('has_voted', sa.Boolean(), nullable=True),
        sa.Column('vote_data', sa.JSON(), nullable=True),
        sa.Column('has_spun', sa.Boolean(), nullable=True),
        sa.Column('invited_by', sa.Integer(), nullable=True),
        sa.Column('invited_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('joined_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('ready_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('voted_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('left_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['invited_by'], ['users.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['session_id'], ['sessions.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('session_id', 'user_id')
    )
    op.create_index('ix_session_participants_id', 'session_participants', ['id'])

    # 6. session_results
    op.create_table('session_results',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('session_id', sa.Integer(), nullable=False),
        sa.Column('session_list_item_id', sa.Integer(), nullable=False),
        sa.Column('total_score', sa.Integer(), nullable=True),
        sa.Column('place', sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(['session_id'], ['sessions.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['session_list_item_id'], ['session_list_items.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('session_id', 'session_list_item_id')
    )
    op.create_index('ix_session_results_id', 'session_results', ['id'])

    # 7. Удаляем таблицы групп
    #op.drop_constraint('lists_group_id_fkey', 'lists', type_='foreignkey')
    op.drop_column('lists', 'group_id')
    op.drop_table('group_members')
    op.drop_table('groups')

def downgrade():
    # Восстанавливаем таблицы групп
    op.create_table('groups',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('owner_id', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['owner_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_table('group_members',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('group_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('role', sa.Enum('ADMIN', 'MEMBER', name='grouprole'), nullable=False),
        sa.Column('joined_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['group_id'], ['groups.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.add_column('lists', sa.Column('group_id', sa.Integer(), nullable=True))
    #op.create_foreign_key('lists_group_id_fkey', 'lists', 'groups',
    op.create_foreign_key( 'lists', 'groups',


['group_id'], ['id'], ondelete='CASCADE')

    # Удаляем таблицы сессий
    op.drop_table('session_results')
    op.drop_table('session_participants')
    op.drop_table('session_list_items')
    op.drop_constraint('fk_sessions_current_list', 'sessions', type_='foreignkey')
    op.drop_table('session_lists')
    op.drop_table('sessions')