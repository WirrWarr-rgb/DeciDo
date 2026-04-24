# tests/test_voting_logic.py
import pytest
import asyncio
from unittest.mock import AsyncMock, MagicMock, patch
from datetime import datetime, timezone

from app.services.session_service import SessionService
from app.models.session import Session, SessionParticipant, SessionStatus, SessionMode
from app.models.list import ItemList, ListItem


class TestVotingLogic:
    """Тесты для логики подсчета голосов."""

    @pytest.fixture
    def mock_db(self):
        """Мок базы данных."""
        return AsyncMock()

    @pytest.fixture
    def sample_items(self):
        """Пример пунктов списка."""
        return [
            ListItem(id=1, name="Item 1", list_id=1, order_index=0),
            ListItem(id=2, name="Item 2", list_id=1, order_index=1),
            ListItem(id=3, name="Item 3", list_id=1, order_index=2),
            ListItem(id=4, name="Item 4", list_id=1, order_index=3),
        ]

    @pytest.fixture
    def sample_session(self, sample_items):
        """Пример сессии."""
        session = Session(
            id=1,
            list_id=1,
            mode=SessionMode.RANKING,
            status=SessionStatus.VOTING
        )
        # Мокаем item_list
        session.item_list = MagicMock()
        session.item_list.items = sample_items
        return session

    def test_ranking_single_vote(self, mock_db, sample_session):
        """Тест 1: Один голос - победитель должен быть первым в его списке."""
        service = SessionService(mock_db)
        
        # Мокаем участника с голосом
        participant = SessionParticipant(
            user_id=1,
            has_voted=True,
            vote_data={"ranked_ids": [1, 2, 3, 4]}  # 1 на первом месте
        )
        sample_session.participants = [participant]
        
        # Вызываем метод подсчета
        loop = asyncio.new_event_loop()
        results = loop.run_until_complete(
            service._calculate_ranking_results(sample_session)
        )
        loop.close()
        
        # Проверяем результаты
        assert results["winner"]["item_id"] == 1
        assert results["results"][0]["total_score"] == 4  # N=4 очков за 1 место
        assert results["results"][1]["total_score"] == 3  # 3 очка за 2 место
        assert results["results"][2]["total_score"] == 2
        assert results["results"][3]["total_score"] == 1

    def test_ranking_multiple_votes_same_winner(self, mock_db, sample_session):
        """Тест 2: Два голоса с одинаковым победителем."""
        service = SessionService(mock_db)
        
        participants = [
            SessionParticipant(
                user_id=1,
                has_voted=True,
                vote_data={"ranked_ids": [1, 2, 3, 4]}
            ),
            SessionParticipant(
                user_id=2,
                has_voted=True,
                vote_data={"ranked_ids": [1, 3, 2, 4]}
            )
        ]
        sample_session.participants = participants
        
        loop = asyncio.new_event_loop()
        results = loop.run_until_complete(
            service._calculate_ranking_results(sample_session)
        )
        loop.close()
        
        # Item 1 должен победить с суммой очков
        assert results["winner"]["item_id"] == 1
        # 1 место у обоих = 4+4 = 8 очков
        assert results["results"][0]["total_score"] == 8

    def test_ranking_different_winners(self, mock_db, sample_session):
        """Тест 3: Разные победители - побеждает с наибольшей суммой."""
        service = SessionService(mock_db)
        
        participants = [
            SessionParticipant(
                user_id=1,
                has_voted=True,
                vote_data={"ranked_ids": [1, 2, 3, 4]}  # 1 первый
            ),
            SessionParticipant(
                user_id=2,
                has_voted=True,
                vote_data={"ranked_ids": [2, 1, 3, 4]}  # 2 первый
            )
        ]
        sample_session.participants = participants
        
        loop = asyncio.new_event_loop()
        results = loop.run_until_complete(
            service._calculate_ranking_results(sample_session)
        )
        loop.close()
        
        # Считаем очки:
        # Участник 1: 1=4, 2=3, 3=2, 4=1
        # Участник 2: 2=4, 1=3, 3=2, 4=1
        # Сумма: 1=7, 2=7, 3=4, 4=2
        # Должна быть ничья, но сортировка поставит кого-то первым
        # Проверяем что очки посчитаны верно
        scores = {r["item_id"]: r["total_score"] for r in results["results"]}
        assert scores[1] == 7
        assert scores[2] == 7
        assert scores[3] == 4
        assert scores[4] == 2

    def test_ranking_all_last_place(self, mock_db, sample_session):
        """Тест 4: Все ставят один и тот же пункт на последнее место."""
        service = SessionService(mock_db)
        
        participants = [
            SessionParticipant(
                user_id=1,
                has_voted=True,
                vote_data={"ranked_ids": [1, 2, 3, 4]}  # 4 последний
            ),
            SessionParticipant(
                user_id=2,
                has_voted=True,
                vote_data={"ranked_ids": [2, 3, 1, 4]}  # 4 последний
            ),
            SessionParticipant(
                user_id=3,
                has_voted=True,
                vote_data={"ranked_ids": [3, 1, 2, 4]}  # 4 последний
            )
        ]
        sample_session.participants = participants
        
        loop = asyncio.new_event_loop()
        results = loop.run_until_complete(
            service._calculate_ranking_results(sample_session)
        )
        loop.close()
        
        # Item 4 должен быть на последнем месте
        assert results["results"][-1]["item_id"] == 4
        # Очки за последнее место: 1 очко * 3 участника = 3
        assert results["results"][-1]["total_score"] == 3

    def test_ranking_complex_scenario(self, mock_db, sample_session):
        """Тест 5: Комплексный сценарий с 5 участниками и 4 пунктами."""
        service = SessionService(mock_db)
        
        participants = [
            SessionParticipant(user_id=1, has_voted=True, vote_data={"ranked_ids": [1, 2, 3, 4]}),
            SessionParticipant(user_id=2, has_voted=True, vote_data={"ranked_ids": [1, 3, 2, 4]}),
            SessionParticipant(user_id=3, has_voted=True, vote_data={"ranked_ids": [2, 1, 4, 3]}),
            SessionParticipant(user_id=4, has_voted=True, vote_data={"ranked_ids": [3, 4, 1, 2]}),
            SessionParticipant(user_id=5, has_voted=True, vote_data={"ranked_ids": [4, 3, 2, 1]}),
        ]
        sample_session.participants = participants
        
        loop = asyncio.new_event_loop()
        results = loop.run_until_complete(
            service._calculate_ranking_results(sample_session)
        )
        loop.close()
        
        # Ручной подсчет для проверки:
        # N=4 очков за 1 место, 3 за 2-е, 2 за 3-е, 1 за 4-е
        # У1: 1=4, 2=3, 3=2, 4=1
        # У2: 1=4, 3=3, 2=2, 4=1
        # У3: 2=4, 1=3, 4=2, 3=1
        # У4: 3=4, 4=3, 1=2, 2=1
        # У5: 4=4, 3=3, 2=2, 1=1
        # Суммы:
        # Item 1: 4+4+3+2+1 = 14
        # Item 2: 3+2+4+1+2 = 12
        # Item 3: 2+3+1+4+3 = 13
        # Item 4: 1+1+2+3+4 = 11
        
        expected_scores = {1: 14, 2: 12, 3: 13, 4: 11}
        
        for r in results["results"]:
            assert r["total_score"] == expected_scores[r["item_id"]]
        
        # Победитель должен быть Item 1
        assert results["winner"]["item_id"] == 1

    def test_random_mode(self, mock_db, sample_session):
        """Тест 6: Режим случайного выбора."""
        sample_session.mode = SessionMode.RANDOM
        
        service = SessionService(mock_db)
        
        # Фиксируем random.seed для детерминированного теста
        import random
        random.seed(42)
        
        loop = asyncio.new_event_loop()
        results = loop.run_until_complete(
            service._calculate_random_results(sample_session)
        )
        loop.close()
        
        # Проверяем структуру результата
        assert "winner" in results
        assert results["winner"]["place"] == 1
        assert results["winner"]["total_score"] == 1
        
        # Только у победителя 1 очко
        for r in results["results"]:
            if r["item_id"] == results["winner"]["item_id"]:
                assert r["total_score"] == 1
            else:
                assert r["total_score"] == 0

    def test_validation_duplicate_ids(self, mock_db):
        """Тест 7: Валидация дубликатов ID."""
        service = SessionService(mock_db)
        
        # Пытаемся провалидировать список с дубликатами
        loop = asyncio.new_event_loop()
        with pytest.raises(ValueError, match="Duplicate item IDs"):
            # Создаем схему с дубликатами
            from app.schemas.session import VoteRequest
            VoteRequest(ranked_item_ids=[1, 2, 2, 3])
        loop.close()

    def test_validation_missing_ids(self, mock_db, sample_items):
        """Тест 8: Валидация неполного списка ID."""
        service = SessionService(mock_db)
        
        # Мокаем запрос к БД
        mock_db.execute.return_value.scalars.return_value.all.return_value = sample_items
        
        loop = asyncio.new_event_loop()
        with pytest.raises(ValueError, match="must contain exactly all list items"):
            loop.run_until_complete(
                service._validate_ranked_ids(1, [1, 2, 3])  # Не хватает 4
            )
        loop.close()