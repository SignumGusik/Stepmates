from datetime import timedelta

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone

from .models import (
    DailySteps,
    EmailVerificationCode,
    FriendRequest,
    Friendship,
    Group,
    GroupMembership,
    PasswordResetCode,
    UserProfile,
    group_avatar_upload_to,
    user_avatar_upload_to,
)
from .serializers import DailyStepsSerializer

User = get_user_model()


class RelationshipModelTests(TestCase):
    def setUp(self):
        self.alice = User.objects.create_user(username="alice", email="alice@example.com", password="pass12345")
        self.bob = User.objects.create_user(username="bob", email="bob@example.com", password="pass12345")

    def test_friendship_make_pair_orders_ids(self):
        expected = tuple(sorted([self.alice.id, self.bob.id]))
        self.assertEqual(Friendship.make_pair(self.bob.id, self.alice.id), expected)
        self.assertEqual(Friendship.make_pair(self.alice.id, self.bob.id), expected)

    def test_friendship_save_normalizes_user_order(self):
        friendship = Friendship.objects.create(user1=self.bob, user2=self.alice)
        friendship.refresh_from_db()
        self.assertLess(friendship.user1_id, friendship.user2_id)

    def test_friend_request_string_is_readable(self):
        request = FriendRequest.objects.create(from_user=self.alice, to_user=self.bob)
        self.assertIn(str(self.alice.id), str(request))
        self.assertIn(str(self.bob.id), str(request))
        self.assertIn(FriendRequest.Status.PENDING, str(request))


class StepsAndProfileModelTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="runner", email="runner@example.com", password="pass12345")

    def test_daily_steps_serializer_marks_completed_goal(self):
        daily = DailySteps.objects.create(
            user=self.user,
            date=timezone.localdate(),
            steps=11000,
            goal_steps=10000,
        )

        data = DailyStepsSerializer(daily).data

        self.assertEqual(data["steps"], 11000)
        self.assertTrue(data["is_goal_completed"])

    def test_user_profile_has_default_goal(self):
        profile = UserProfile.objects.create(user=self.user)
        self.assertEqual(profile.daily_goal_steps, 10000)
        self.assertIn(str(self.user.id), str(profile))

    def test_avatar_upload_paths_keep_file_extension(self):
        profile = UserProfile(user=self.user)
        group = Group(name="Walkers", created_by=self.user)

        user_path = user_avatar_upload_to(profile, "photo.PNG")
        group_path = group_avatar_upload_to(group, "cover.webp")

        self.assertTrue(user_path.startswith(f"avatars/user_{self.user.id}/"))
        self.assertTrue(user_path.endswith(".png"))
        self.assertTrue(group_path.startswith("avatars/group_new/"))
        self.assertTrue(group_path.endswith(".webp"))


class ExpiringCodeModelTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="mail", email="mail@example.com", password="pass12345")

    def test_password_reset_code_expiry(self):
        fresh = PasswordResetCode.objects.create(
            user=self.user,
            code="123456",
            expires_at=timezone.now() + timedelta(minutes=5),
        )
        expired = PasswordResetCode.objects.create(
            user=self.user,
            code="654321",
            expires_at=timezone.now() - timedelta(minutes=1),
        )

        self.assertFalse(fresh.is_expired())
        self.assertTrue(expired.is_expired())

    def test_email_verification_default_expiry_is_in_future(self):
        expires_at = EmailVerificationCode.default_expiry()
        self.assertGreater(expires_at, timezone.now())
        self.assertLess(expires_at, timezone.now() + timedelta(minutes=11))


class GroupModelTests(TestCase):
    def test_group_membership_is_unique_per_user(self):
        owner = User.objects.create_user(username="owner", email="owner@example.com", password="pass12345")
        group = Group.objects.create(name="Team", created_by=owner)
        GroupMembership.objects.create(group=group, user=owner, is_admin=True)

        self.assertEqual(group.memberships.count(), 1)
        self.assertEqual(str(group), f"Group({group.id}): Team")
