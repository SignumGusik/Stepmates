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
    GroupHidden,
    GroupInvite,
    GroupMembership,
    MatchedTrackSegment,
    PasswordResetCode,
    UserLiveLocation,
    UserProfile,
)

User = get_user_model()


def friendship_kwargs(a, b):
    first_id, second_id = sorted([a.id, b.id])
    return {"user1_id": first_id, "user2_id": second_id}


class AuthFlowApiCoverageTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    @patch("api.utils.send_password_reset_email", return_value=True)
    def test_password_reset_request_returns_success_message(self, send_email):
        user = User.objects.create_user(username="reset@example.com", email="reset@example.com", password="old-password")

        response = self.client.post("/api/password-reset/", {"email": "reset@example.com"}, format="json")

        self.assertEqual(response.status_code, 200)
        self.assertIn("Код", response.data["detail"])
        send_email.assert_called_once_with(user)

    def test_password_reset_verify_and_confirm_change_password(self):
        user = User.objects.create_user(username="confirm@example.com", email="confirm@example.com", password="old-password")
        PasswordResetCode.objects.create(
            user=user,
            code="123456",
            expires_at=timezone.now() + timedelta(minutes=10),
        )

        verify_response = self.client.post(
            "/api/password-reset/verify/",
            {"email": "confirm@example.com", "code": "123456"},
            format="json",
        )
        confirm_response = self.client.post(
            "/api/password-reset/confirm/",
            {
                "email": "confirm@example.com",
                "code": "123456",
                "password": "new-password",
                "password2": "new-password",
            },
            format="json",
        )

        self.assertEqual(verify_response.status_code, 200)
        self.assertEqual(confirm_response.status_code, 200)
        user.refresh_from_db()
        self.assertTrue(user.check_password("new-password"))
        self.assertTrue(PasswordResetCode.objects.get(user=user, code="123456").is_used)

    def test_register_verify_activates_user_and_returns_tokens(self):
        user = User.objects.create_user(
            username="verify@example.com",
            email="verify@example.com",
            password="password123",
            is_active=False,
        )
        EmailVerificationCode.objects.create(
            user=user,
            code="654321",
            expires_at=timezone.now() + timedelta(minutes=10),
        )

        response = self.client.post(
            "/api/register/verify/",
            {"email": "verify@example.com", "code": "654321"},
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)
        user.refresh_from_db()
        self.assertTrue(user.is_active)

    @override_settings(DISABLE_EMAIL=True)
    def test_register_resend_creates_new_code(self):
        user = User.objects.create_user(username="resend@example.com", email="resend@example.com", password="password123")

        response = self.client.post("/api/register/resend/", {"email": "resend@example.com"}, format="json")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(EmailVerificationCode.objects.filter(user=user, is_used=False).count(), 1)


class SocialApiCoverageTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.me = User.objects.create_user(username="me", email="me@example.com", password="pass12345")
        self.friend = User.objects.create_user(username="friend", email="friend@example.com", password="pass12345")
        self.other = User.objects.create_user(username="other", email="other@example.com", password="pass12345")
        self.mutual = User.objects.create_user(username="mutual", email="mutual@example.com", password="pass12345")
        UserProfile.objects.create(user=self.me, daily_goal_steps=9000)
        UserProfile.objects.create(user=self.friend, daily_goal_steps=10000)
        UserProfile.objects.create(user=self.other, daily_goal_steps=10000)
        UserProfile.objects.create(user=self.mutual, daily_goal_steps=10000)
        Friendship.objects.create(**friendship_kwargs(self.me, self.friend))
        Friendship.objects.create(**friendship_kwargs(self.me, self.mutual))
        Friendship.objects.create(**friendship_kwargs(self.friend, self.mutual))
        self.client.force_authenticate(self.me)

    def test_login_data_and_profile_return_aggregated_user_info(self):
        today = timezone.localdate()
        DailySteps.objects.create(user=self.me, date=today, steps=9000, goal_steps=9000)
        DailySteps.objects.create(user=self.me, date=today - timedelta(days=1), steps=8000, goal_steps=8000)

        login_response = self.client.get("/api/login_data/")
        profile_response = self.client.get("/api/profile/me/")

        self.assertEqual(login_response.status_code, 200)
        self.assertEqual(profile_response.status_code, 200)
        self.assertEqual(profile_response.data["current_streak_days"], 2)
        self.assertEqual(profile_response.data["friends_count"], 2)
        self.assertGreaterEqual(len(profile_response.data["achievements"]), 1)

    def test_set_username_updates_current_user(self):
        response = self.client.post("/api/profile/username/", {"username": "fresh_name"}, format="json")

        self.assertEqual(response.status_code, 200)
        self.me.refresh_from_db()
        self.assertEqual(self.me.username, "fresh_name")
        self.assertEqual(response.data["username"], "fresh_name")

    def test_user_search_friends_and_user_card_include_relationship_flags(self):
        FriendRequest.objects.create(from_user=self.me, to_user=self.other)

        search_response = self.client.get("/api/users/?q=friend")
        friends_response = self.client.get("/api/friends/")
        card_response = self.client.get(f"/api/users/{self.friend.id}/card/")

        self.assertEqual(search_response.status_code, 200)
        self.assertEqual(friends_response.status_code, 200)
        self.assertEqual(card_response.status_code, 200)
        self.assertTrue(card_response.data["is_friend"])
        self.assertEqual(card_response.data["mutual_friends_count"], 1)
        self.assertGreaterEqual(len(friends_response.data), 2)

    def test_friend_request_create_incoming_outgoing_accept_reject_cancel_and_remove(self):
        create_response = self.client.post("/api/friend-requests/", {"to_user_id": self.other.id}, format="json")
        outgoing_response = self.client.get("/api/friend-requests/outgoing/")
        cancel_response = self.client.delete(f"/api/friend-requests/{self.other.id}/cancel/")

        incoming_request = FriendRequest.objects.create(from_user=self.other, to_user=self.me)
        incoming_response = self.client.get("/api/friend-requests/incoming/")
        accept_response = self.client.post(f"/api/friend-requests/{incoming_request.id}/accept/")

        rejected_request = FriendRequest.objects.create(from_user=self.other, to_user=self.me)
        reject_response = self.client.post(f"/api/friend-requests/{rejected_request.id}/reject/")

        remove_response = self.client.delete(f"/api/friends/{self.other.id}/")

        self.assertEqual(create_response.status_code, 201)
        self.assertEqual(outgoing_response.status_code, 200)
        self.assertEqual(cancel_response.status_code, 204)
        self.assertEqual(incoming_response.status_code, 200)
        self.assertEqual(accept_response.status_code, 200)
        self.assertEqual(reject_response.status_code, 200)
        self.assertEqual(remove_response.status_code, 204)

    def test_friends_leaderboard_and_map_ranking_return_places(self):
        today = timezone.localdate()
        DailySteps.objects.create(user=self.me, date=today, steps=7000, goal_steps=9000)
        DailySteps.objects.create(user=self.friend, date=today, steps=12000, goal_steps=10000)
        DailySteps.objects.create(user=self.mutual, date=today, steps=5000, goal_steps=10000)

        leaderboard_response = self.client.get("/api/friends/leaderboard/?period=today")
        map_ranking_response = self.client.get("/api/map/ranking/")

        self.assertEqual(leaderboard_response.status_code, 200)
        self.assertEqual(leaderboard_response.data[0]["user_id"], self.friend.id)
        self.assertEqual(map_ranking_response.status_code, 200)
        self.assertEqual(map_ranking_response.data["my_place"], 2)

    def test_profile_avatar_delete_is_idempotent(self):
        response = self.client.delete("/api/profile/avatar/")
        self.assertEqual(response.status_code, 204)


class GroupAndMapApiCoverageTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(username="owner", email="owner2@example.com", password="pass12345")
        self.member = User.objects.create_user(username="member", email="member2@example.com", password="pass12345")
        self.friend = User.objects.create_user(username="groupfriend", email="groupfriend@example.com", password="pass12345")
        Friendship.objects.create(**friendship_kwargs(self.owner, self.friend))
        self.group = Group.objects.create(name="Coverage", status="morning", created_by=self.owner, goal_steps=10000)
        GroupMembership.objects.create(group=self.group, user=self.owner, is_admin=True)
        GroupMembership.objects.create(group=self.group, user=self.member, is_admin=False)
        self.client.force_authenticate(self.owner)

    def test_group_create_detail_patch_members_and_avatar_delete(self):
        create_response = self.client.post(
            "/api/groups/",
            {"name": "New group", "description": "walk", "status": "active", "goal_steps": 15000},
            format="json",
        )
        detail_response = self.client.get(f"/api/groups/{self.group.id}/")
        patch_response = self.client.patch(
            f"/api/groups/{self.group.id}/",
            {"name": "Coverage Updated", "status": "evening", "goal_steps": 14000},
            format="json",
        )
        members_response = self.client.get(f"/api/groups/{self.group.id}/members/")
        avatar_delete_response = self.client.delete(f"/api/groups/{self.group.id}/avatar/")

        self.assertEqual(create_response.status_code, 201)
        self.assertEqual(detail_response.status_code, 200)
        self.assertEqual(patch_response.status_code, 200)
        self.assertEqual(patch_response.data["name"], "Coverage Updated")
        self.assertEqual(members_response.status_code, 200)
        self.assertEqual(avatar_delete_response.status_code, 200)

    def test_group_invite_accept_reject_and_notifications(self):
        invite_response = self.client.post(
            f"/api/groups/{self.group.id}/members/",
            {"user_id": self.friend.id},
            format="json",
        )
        invite = GroupInvite.objects.get(group=self.group, to_user=self.friend)

        self.client.force_authenticate(self.friend)
        notifications_response = self.client.get("/api/notifications/")
        accept_response = self.client.post(f"/api/group-invites/{invite.id}/accept/")

        second_invite = GroupInvite.objects.create(group=self.group, from_user=self.owner, to_user=self.friend)
        reject_response = self.client.post(f"/api/group-invites/{second_invite.id}/reject/")

        self.assertEqual(invite_response.status_code, 201)
        self.assertEqual(notifications_response.status_code, 200)
        self.assertEqual(notifications_response.data[0]["type"], "group_invite")
        self.assertEqual(accept_response.status_code, 200)
        self.assertTrue(GroupMembership.objects.filter(group=self.group, user=self.friend).exists())
        self.assertEqual(reject_response.status_code, 200)

    def test_group_admin_promote_demote_remove_leave_and_delete(self):
        promote_response = self.client.post(f"/api/groups/{self.group.id}/members/{self.member.id}/promote/")
        demote_response = self.client.post(f"/api/groups/{self.group.id}/members/{self.member.id}/demote/")
        remove_response = self.client.delete(f"/api/groups/{self.group.id}/members/{self.member.id}/")

        GroupMembership.objects.create(group=self.group, user=self.friend, is_admin=False)
        self.client.force_authenticate(self.friend)
        leave_response = self.client.post(f"/api/groups/{self.group.id}/leave/")

        self.client.force_authenticate(self.owner)
        delete_response = self.client.delete(f"/api/groups/{self.group.id}/delete/")

        self.assertEqual(promote_response.status_code, 200)
        self.assertEqual(demote_response.status_code, 200)
        self.assertEqual(remove_response.status_code, 204)
        self.assertEqual(leave_response.status_code, 204)
        self.assertEqual(delete_response.status_code, 204)

    def test_map_group_endpoints_return_live_tracks_and_rankings(self):
        now = timezone.now()
        DailySteps.objects.create(user=self.owner, date=timezone.localdate(), steps=10000, goal_steps=10000)
        DailySteps.objects.create(user=self.member, date=timezone.localdate(), steps=15000, goal_steps=10000)
        UserLiveLocation.objects.create(
            user=self.owner,
            latitude=55.7,
            longitude=37.6,
            horizontal_accuracy=8,
            confidence_score=90,
            movement_kind="walking",
            signal_quality="good",
            is_sharing=True,
        )
        UserLiveLocation.objects.create(
            user=self.member,
            latitude=55.8,
            longitude=37.7,
            horizontal_accuracy=60,
            confidence_score=40,
            movement_kind="signal_lost",
            signal_quality="poor",
            is_sharing=True,
        )
        MatchedTrackSegment.objects.create(
            user=self.member,
            day=timezone.localdate(),
            started_at=now,
            ended_at=now + timedelta(minutes=3),
            raw_points=[],
            display_points=[{"latitude": 55.8, "longitude": 37.7}],
            movement_kind="walking",
            confidence_score=80,
            signal_quality="good",
            matching_confidence="high",
            status=MatchedTrackSegment.STATUS_MATCHED,
        )

        map_groups_response = self.client.get("/api/map/groups/")
        live_response = self.client.get(f"/api/map/groups/{self.group.id}/live/")
        tracks_response = self.client.get(f"/api/map/groups/{self.group.id}/matched-tracks/?day=today")
        ranking_response = self.client.get(f"/api/map/groups/{self.group.id}/ranking/")

        self.assertEqual(map_groups_response.status_code, 200)
        self.assertEqual(live_response.status_code, 200)
        self.assertGreaterEqual(len(live_response.data), 2)
        self.assertEqual(tracks_response.status_code, 200)
        self.assertEqual(tracks_response.data[0]["user_id"], self.member.id)
        self.assertEqual(ranking_response.status_code, 200)
        self.assertEqual(ranking_response.data["my_place"], 2)

    def test_hidden_group_is_excluded_from_groups_list(self):
        GroupHidden.objects.create(group=self.group, user=self.owner)

        response = self.client.get("/api/groups/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data, [])
