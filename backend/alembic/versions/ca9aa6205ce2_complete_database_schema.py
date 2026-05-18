"""Complete database schema

Revision ID: ca9aa6205ce2
Revises: 
Create Date: 2026-04-26 18:11:05.153573

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ca9aa6205ce2'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ============================================
    # 1. Базовые таблицы, не зависящие от других
    # ============================================
    
    # Таблица users (базовая)
    op.create_table('users',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('username', sa.String(), nullable=False),
        sa.Column('email', sa.String(), nullable=False),
        sa.Column('hashed_password', sa.String(), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)
    op.create_index(op.f('ix_users_id'), 'users', ['id'], unique=False)
    op.create_index(op.f('ix_users_username'), 'users', ['username'], unique=True)
    
    # Таблица lists (зависит только от users)
    op.create_table('lists',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_lists_id'), 'lists', ['id'], unique=False)
    
    # Таблица friends (зависит от users)
    op.create_table('friends',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('friend_id', sa.Integer(), nullable=False),
        sa.Column('status', sa.Enum('PENDING', 'ACCEPTED', 'REJECTED', name='friendstatus'), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['friend_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_friends_id'), 'friends', ['id'], unique=False)
    
    # Таблица list_items (зависит от lists)
    op.create_table('list_items',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('list_id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=200), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('image_url', sa.String(length=500), nullable=True),
        sa.Column('order_index', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['list_id'], ['lists.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_list_items_id'), 'list_items', ['id'], unique=False)
    
    # ============================================
    # 2. Таблицы сессий (зависят от users)
    # ============================================
    
    # Таблица sessions (зависит от users)
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
    op.create_index(op.f('ix_sessions_id'), 'sessions', ['id'], unique=False)
    
    # Таблица session_lists (зависит от sessions и lists)
    op.create_table('session_lists',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('session_id', sa.Integer(), nullable=False),
        sa.Column('original_list_id', sa.Integer(), nullable=True),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['original_list_id'], ['lists.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['session_id'], ['sessions.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_session_lists_id'), 'session_lists', ['id'], unique=False)
    
    # Добавляем внешний ключ sessions.current_list_id -> session_lists.id
    op.create_foreign_key(
        'fk_sessions_current_list_id', 
        'sessions', 'session_lists', 
        ['current_list_id'], ['id'], 
        ondelete='SET NULL'
    )
    
    # Таблица session_list_items (зависит от session_lists и users)
    op.create_table('session_list_items',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('session_list_id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=200), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('image_url', sa.String(length=500), nullable=True),
        sa.Column('order_index', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_by', sa.Integer(), nullable=True),
        sa.Column('edited_by', sa.Integer(), nullable=True),
        sa.Column('edited_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['created_by'], ['users.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['edited_by'], ['users.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['session_list_id'], ['session_lists.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_session_list_items_id'), 'session_list_items', ['id'], unique=False)
    
    # Таблица session_participants (зависит от sessions и users)
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
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_session_participants_id'), 'session_participants', ['id'], unique=False)
    
    # Таблица session_results (зависит от sessions и session_list_items)
    op.create_table('session_results',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('session_id', sa.Integer(), nullable=False),
        sa.Column('session_list_item_id', sa.Integer(), nullable=False),
        sa.Column('total_score', sa.Integer(), nullable=True),
        sa.Column('place', sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(['session_id'], ['sessions.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['session_list_item_id'], ['session_list_items.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_session_results_id'), 'session_results', ['id'], unique=False)


def downgrade() -> None:
    # Удаляем в обратном порядке (от зависимых к базовым)
    
    # Таблицы результатов сессий
    op.drop_index(op.f('ix_session_results_id'), table_name='session_results')
    op.drop_table('session_results')
    
    # Участники и элементы сессий
    op.drop_index(op.f('ix_session_participants_id'), table_name='session_participants')
    op.drop_table('session_participants')
    
    op.drop_index(op.f('ix_session_list_items_id'), table_name='session_list_items')
    op.drop_table('session_list_items')
    
    # Удаляем внешний ключ sessions -> session_lists
    op.drop_constraint('fk_sessions_current_list_id', 'sessions', type_='foreignkey')
    
    # Session lists
    op.drop_index(op.f('ix_session_lists_id'), table_name='session_lists')
    op.drop_table('session_lists')
    
    # Sessions
    op.drop_index(op.f('ix_sessions_id'), table_name='sessions')
    op.drop_table('sessions')
    
    # Базовые таблицы
    op.drop_index(op.f('ix_list_items_id'), table_name='list_items')
    op.drop_table('list_items')
    
    op.drop_index(op.f('ix_friends_id'), table_name='friends')
    op.drop_table('friends')
    
    op.drop_index(op.f('ix_lists_id'), table_name='lists')
    op.drop_table('lists')
    
    # Users (дропаем ENUM типы после таблиц)
    op.drop_index(op.f('ix_users_username'), table_name='users')
    op.drop_index(op.f('ix_users_id'), table_name='users')
    op.drop_index(op.f('ix_users_email'), table_name='users')
    op.drop_table('users')
    
    # Удаляем ENUM типы (PostgreSQL)
    op.execute('DROP TYPE IF EXISTS friendstatus CASCADE')
    op.execute('DROP TYPE IF EXISTS sessionmode CASCADE')
    op.execute('DROP TYPE IF EXISTS sessionstatus CASCADE')
    op.execute('DROP TYPE IF EXISTS participantstatus CASCADE')