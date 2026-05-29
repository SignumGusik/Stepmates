from datetime import timedelta
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from .models import (
    DailySteps,
    EmailVerificationCode,
    FriendRequest,
    Friendship,
    Group,
    GroupMembership,
    MatchedTrackSegment,
    UserLiveLocation,
    UserProfile,
    UserTrackPoint,
)

User = get_user_model()


class AuthAndRegistrationAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()

    @override_settings(DISABLE_EMAIL=True)
    def test_register_creates_inactive_user_and_verification_code(self):
        response = self.client.post(
            "/api/register/",
            {"email": "new@example.com", "password": "strong-password", "password2": "strong-password"},
            format="json",
        )

        self.assertEqual(response.status_code, 201)
        user = User.objects.get(email="new@example.com")
        self.assertFalse(user.is_active)
        self.assertEqual(EmailVerificationCode.objects.filter(user=user, is_used=False).count(), 1)

    def test_token_endpoint_reports_wrong_password_cleanly(self):
        User.objects.create_user(
            username="login@example.com",
            email="login@example.com",
            password="right-password",
            is_active=True,
        )

        response = self.client.post(
            "/api/auth/token/",
            {"email": "login@example.com", "password": "wrong-password"},
            format="json",
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("Неверный пароль", str(response.data))


class StepsAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username="steps", email="steps@example.com", password="pass12345")
        self.client.force_authenticate(self.user)

    def test_sync_steps_creates_daily_row_with_profile_goal(self):
        UserProfile.objects.create(user=self.user, daily_goal_steps=12000)

        response = self.client.post("/api/steps/sync/", {"steps": 9000}, format="json")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["steps"], 9000)
        self.assertEqual(response.data["goal_steps"], 12000)
        self.assertFalse(response.data["is_goal_completed"])
        self.assertTrue(DailySteps.objects.filter(user=self.user, date=timezone.localdate()).exists())

    def test_update_daily_goal_updates_profile_and_today_row(self):
        DailySteps.objects.create(user=self.user, date=timezone.localdate(), steps=15000, goal_steps=10000)

        response = self.client.patch("/api/steps/goal/", {"daily_goal_steps": 14000}, format="json")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["daily_goal_steps"], 14000)
        self.assertTrue(response.data["is_goal_completed"])
        self.user.profile.refresh_from_db()
        self.assertEqual(self.user.profile.daily_goal_steps, 14000)
        self.assertEqual(DailySteps.objects.get(user=self.user, date=timezone.localdate()).goal_steps, 14000)

    def test_today_steps_returns_default_when_no_row_exists(self):
        UserProfile.objects.create(user=self.user, daily_goal_steps=8000)

        response = self.client.get("/api/steps/me/today/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["steps"], 0)
        self.assertEqual(response.data["goal_steps"], 8000)
        self.assertFalse(response.data["is_goal_completed"])


class MapAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username="map", email="map@example.com", password="pass12345")
        self.friend = User.objects.create_user(username="friend", email="friend@example.com", password="pass12345")
        Friendship.objects.create(**self._friendship_kwargs(self.user, self.friend))
        self.client.force_authenticate(self.user)

    def _friendship_kwargs(self, a, b):
        first_id, second_id = sorted([a.id, b.id])
        return {
            "user1_id": first_id,
            "user2_id": second_id,
        }

    def test_live_location_update_normalizes_quality(self):
        response = self.client.post(
            "/api/map/live-location/",
            {
                "latitude": 55.751,
                "longitude": 37.618,
                "horizontal_accuracy": 8,
                "speed": 1.2,
                "movement_state": "walking",
                "confidence_score": 93,
                "is_sharing": True,
            },
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        live = UserLiveLocation.objects.get(user=self.user)
        self.assertEqual(live.movement_kind, "walking")
        self.assertEqual(live.signal_quality, "good")
        self.assertEqual(live.confidence_score, 93)

    @patch("api.views.rebuild_user_matched_segments_throttled", return_value=True)
    def test_track_points_upload_creates_points(self, rebuild):
        now = timezone.now()
        response = self.client.post(
            "/api/map/track-points/",
            {
                "points": [
                    {
                        "latitude": 55.751,
                        "longitude": 37.618,
                        "horizontal_accuracy": 8,
                        "speed": 1.2,
                        "course": 90,
                        "movement_state": "walking",
                        "movement_kind": "walking",
                        "confidence_score": 92,
                        "steps_delta": 10,
                        "recorded_at": now.isoformat(),
                    },
                    {
                        "latitude": 55.752,
                        "longitude": 37.619,
                        "horizontal_accuracy": 9,
                        "speed": 1.3,
                        "course": 90,
                        "movement_state": "walking",
                        "movement_kind": "walking",
                        "confidence_score": 90,
                        "steps_delta": 11,
                        "recorded_at": (now + timedelta(seconds=10)).isoformat(),
                    },
                ]
            },
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["created"], 2)
        self.assertEqual(UserTrackPoint.objects.filter(user=self.user).count(), 2)
        rebuild.assert_called()

    def test_my_track_returns_uploaded_points(self):
        UserTrackPoint.objects.create(
            user=self.user,
            latitude=55.751,
            longitude=37.618,
            horizontal_accuracy=8,
            speed=1.2,
            course=90,
            movement_state="walking",
            movement_kind="walking",
            confidence_score=90,
            steps_delta=4,
            recorded_at=timezone.now(),
            day=timezone.localdate(),
        )

        response = self.client.get("/api/map/my-track/?day=today")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["movement_kind"], "walking")

    def test_friends_live_location_returns_only_friends(self):
        UserLiveLocation.objects.create(
            user=self.friend,
            latitude=44.1,
            longitude=39.0,
            horizontal_accuracy=80,
            confidence_score=30,
            movement_kind="signal_lost",
            signal_quality="poor",
            is_sharing=True,
        )

        response = self.client.get("/api/map/friends-live/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["user_id"], self.friend.id)
        self.assertEqual(response.data[0]["signal_quality"], "poor")

    def test_my_matched_track_returns_segments(self):
        now = timezone.now()
        MatchedTrackSegment.objects.create(
            user=self.user,
            day=timezone.localdate(),
            started_at=now,
            ended_at=now + timedelta(minutes=2),
            raw_points=[],
            display_points=[{"latitude": 55.751, "longitude": 37.618}],
            movement_kind="walking",
            confidence_score=90,
            signal_quality="good",
            matching_confidence="high",
            status=MatchedTrackSegment.STATUS_MATCHED,
        )

        response = self.client.get("/api/map/my-matched-track/?day=today")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["status"], "matched")


class GroupAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(username="owner", email="owner@example.com", password="pass12345")
        self.member = User.objects.create_user(username="member", email="member@example.com", password="pass12345")
        self.group = Group.objects.create(name="Morning", created_by=self.owner, goal_steps=10000)
        GroupMembership.objects.create(group=self.group, user=self.owner, is_admin=True)
        GroupMembership.objects.create(group=self.group, user=self.member, is_admin=False)
        self.client.force_authenticate(self.owner)

    def test_groups_list_contains_members_count_and_admin_flag(self):
        response = self.client.get("/api/groups/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data[0]["members_count"], 2)
        self.assertTrue(response.data[0]["is_admin"])

    def test_group_leaderboard_sorts_by_steps_for_week(self):
        today = timezone.localdate()
        DailySteps.objects.create(user=self.owner, date=today, steps=5000, goal_steps=10000)
        DailySteps.objects.create(user=self.member, date=today, steps=12000, goal_steps=10000)

        response = self.client.get(f"/api/groups/{self.group.id}/leaderboard/?period=week")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data[0]["user_id"], self.member.id)
        self.assertEqual(response.data[0]["place"], 1)
        self.assertEqual(response.data[1]["user_id"], self.owner.id)

    def test_group_leaderboard_rejects_bad_period(self):
        response = self.client.get(f"/api/groups/{self.group.id}/leaderboard/?period=year")

        self.assertEqual(response.status_code, 400)
        self.assertIn("Invalid period", response.data["detail"])


class NotificationAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.me = User.objects.create_user(username="me", email="me@example.com", password="pass12345")
        self.other = User.objects.create_user(username="other", email="other@example.com", password="pass12345")
        self.client.force_authenticate(self.me)

    def test_notifications_include_incoming_friend_request(self):
        FriendRequest.objects.create(from_user=self.other, to_user=self.me)

        response = self.client.get("/api/notifications/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]["type"], "friend_request")
