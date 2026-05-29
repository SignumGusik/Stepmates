from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import RequestFactory, TestCase
from django.utils import timezone
from rest_framework.test import APIRequestFactory

from .models import DailySteps, Friendship, UserProfile
from .serializers import (
    CreateFriendRequestSerializer,
    DailyGoalSerializer,
    DailyStepsSyncSerializer,
    EmailTokenObtainPairSerializer,
    LiveLocationUpdateSerializer,
    SetUsernameSerializer,
    TrackPointsBatchSerializer,
    UserShortSerializer,
)

User = get_user_model()


class StepsSerializerTests(TestCase):
    def test_daily_steps_rejects_future_date(self):
        serializer = DailyStepsSyncSerializer(
            data={"steps": 1000, "date": timezone.localdate() + timedelta(days=1)}
        )
        self.assertFalse(serializer.is_valid())
        self.assertIn("date", serializer.errors)

    def test_daily_goal_accepts_professional_range(self):
        serializer = DailyGoalSerializer(data={"daily_goal_steps": 15000})
        self.assertTrue(serializer.is_valid(), serializer.errors)
        self.assertEqual(serializer.validated_data["daily_goal_steps"], 15000)

    def test_daily_goal_rejects_too_small_value(self):
        serializer = DailyGoalSerializer(data={"daily_goal_steps": 999})
        self.assertFalse(serializer.is_valid())
        self.assertIn("daily_goal_steps", serializer.errors)


class AuthSerializerTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username="active@example.com",
            email="active@example.com",
            password="strong-password",
            is_active=True,
        )

    def test_email_token_serializer_returns_tokens_and_user_payload(self):
        serializer = EmailTokenObtainPairSerializer(
            data={"email": "ACTIVE@example.com", "password": "strong-password"},
            context={"request": RequestFactory().post("/api/auth/token/")},
        )

        self.assertTrue(serializer.is_valid(), serializer.errors)
        self.assertIn("access", serializer.validated_data)
        self.assertIn("refresh", serializer.validated_data)
        self.assertEqual(serializer.validated_data["user"]["email"], "active@example.com")

    def test_email_token_serializer_reports_wrong_password(self):
        serializer = EmailTokenObtainPairSerializer(
            data={"email": "active@example.com", "password": "wrong-password"},
            context={"request": RequestFactory().post("/api/auth/token/")},
        )

        self.assertFalse(serializer.is_valid())
        self.assertIn("Неверный пароль", str(serializer.errors))


class SocialSerializerTests(TestCase):
    def setUp(self):
        self.me = User.objects.create_user(username="me", email="me@example.com", password="pass12345")
        self.friend = User.objects.create_user(username="friend", email="friend@example.com", password="pass12345")
        self.other = User.objects.create_user(username="other", email="other@example.com", password="pass12345")
        self.request = APIRequestFactory().get("/api/users/")
        self.request.user = self.me

    def test_user_short_serializer_uses_context_flags(self):
        serializer = UserShortSerializer(
            self.friend,
            context={
                "request": self.request,
                "friends_ids": {self.friend.id},
                "sent_pending_ids": {self.other.id},
                "received_pending_ids": set(),
            },
        )

        data = serializer.data
        self.assertTrue(data["is_friend"])
        self.assertFalse(data["request_sent"])
        self.assertFalse(data["request_received"])

    def test_create_friend_request_rejects_self_request(self):
        serializer = CreateFriendRequestSerializer(
            data={"to_user_id": self.me.id},
            context={"request": self.request},
        )

        self.assertFalse(serializer.is_valid())
        self.assertIn("to_user_id", serializer.errors)

    def test_set_username_rejects_duplicate_case_insensitive(self):
        User.objects.create_user(username="TakenName", email="taken@example.com", password="pass12345")
        serializer = SetUsernameSerializer(
            data={"username": "takenname"},
            context={"request": self.request},
        )

        self.assertFalse(serializer.is_valid())
        self.assertIn("username", serializer.errors)

    def test_set_username_accepts_letters_digits_and_underscore(self):
        serializer = SetUsernameSerializer(
            data={"username": "nice_name_123"},
            context={"request": self.request},
        )

        self.assertTrue(serializer.is_valid(), serializer.errors)
        self.assertEqual(serializer.validated_data["username"], "nice_name_123")


class MapSerializerTests(TestCase):
    def test_live_location_rejects_impossible_coordinates(self):
        serializer = LiveLocationUpdateSerializer(data={"latitude": 120, "longitude": 37})
        self.assertFalse(serializer.is_valid())
        self.assertIn("latitude", serializer.errors)

    def test_track_points_batch_accepts_rich_point_payload(self):
        serializer = TrackPointsBatchSerializer(data={
            "points": [
                {
                    "latitude": 55.751,
                    "longitude": 37.618,
                    "horizontal_accuracy": 8,
                    "speed": 1.2,
                    "course": 90,
                    "movement_state": "walking",
                    "movement_kind": "walking",
                    "break_reason": None,
                    "confidence_score": 94,
                    "steps_delta": 12,
                    "recorded_at": timezone.now().isoformat(),
                }
            ]
        })

        self.assertTrue(serializer.is_valid(), serializer.errors)
        self.assertEqual(serializer.validated_data["points"][0]["confidence_score"], 94)

    def test_track_points_batch_rejects_bad_longitude(self):
        serializer = TrackPointsBatchSerializer(data={
            "points": [{"latitude": 55.751, "longitude": 200, "recorded_at": timezone.now().isoformat()}]
        })

        self.assertFalse(serializer.is_valid())
        self.assertIn("longitude", serializer.errors["points"][0])
