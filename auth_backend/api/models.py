from django.conf import settings
from django.db import models
from django.db.models import Q, F
from django.utils import timezone
from datetime import timedelta
import os
import uuid


User = settings.AUTH_USER_MODEL


class FriendRequest(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        ACCEPTED = "accepted", "Accepted"
        REJECTED = "rejected", "Rejected"

    from_user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="friend_requests_sent"
    )
    to_user = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="friend_requests_received"
    )
    status = models.CharField(
        max_length=16, choices=Status.choices, default=Status.PENDING
    )
    created_at = models.DateTimeField(auto_now_add=True)
    seen_by_from_user = models.BooleanField(default=False)

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=~Q(from_user=F("to_user")),
                name="friend_request_not_to_self",
            ),
            models.UniqueConstraint(
                fields=["from_user", "to_user"],
                condition=Q(status="pending"),
                name="unique_pending_friend_request",
            ),
        ]
        indexes = [
            models.Index(fields=["to_user", "status"]),
            models.Index(fields=["from_user", "status"]),
        ]

    def __str__(self):
        return f"{self.from_user_id} -> {self.to_user_id} ({self.status})"


class Friendship(models.Model):
    user1 = models.ForeignKey(User, on_delete=models.CASCADE, related_name="friendships_as_user1")
    user2 = models.ForeignKey(User, on_delete=models.CASCADE, related_name="friendships_as_user2")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=Q(user1__lt=F("user2")),
                name="friendship_user1_lt_user2",
            ),
            models.UniqueConstraint(fields=["user1", "user2"], name="unique_friendship_pair"),
        ]
        indexes = [
            models.Index(fields=["user1"]),
            models.Index(fields=["user2"]),
        ]

    def save(self, *args, **kwargs):
        if self.user1_id and self.user2_id and self.user1_id > self.user2_id:
            self.user1_id, self.user2_id = self.user2_id, self.user1_id
        super().save(*args, **kwargs)

    @staticmethod
    def make_pair(a_id: int, b_id: int):
        return (a_id, b_id) if a_id < b_id else (b_id, a_id)

    def __str__(self):
        return f"{self.user1_id} <-> {self.user2_id}"

def group_avatar_upload_to(instance, filename):
    ext = os.path.splitext(filename or "")[1].lower() or ".jpg"
    return f"avatars/group_{instance.id or 'new'}/{uuid.uuid4().hex}{ext}"


class Group(models.Model):
    name = models.CharField(max_length=120)
    description = models.TextField(blank=True, default="")
    avatar = models.ImageField(upload_to=group_avatar_upload_to, null=True, blank=True)
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name="groups_created")
    created_at = models.DateTimeField(auto_now_add=True)
    members = models.ManyToManyField(
        User,
        through="GroupMembership",
        through_fields=("group", "user"),
        related_name="chat_groups"
    )
    status = models.CharField(max_length=160, blank=True, default="")
    goal_steps = models.PositiveIntegerField(default=300000)

    def __str__(self):
        return f"Group({self.id}): {self.name}"


class GroupMembership(models.Model):
    group = models.ForeignKey(Group, on_delete=models.CASCADE, related_name="memberships")
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="group_memberships")
    is_admin = models.BooleanField(default=False)
    added_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="group_members_added",
    )

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["group", "user"], name="unique_group_member"),
        ]
        indexes = [
            models.Index(fields=["group"]),
            models.Index(fields=["user"]),
        ]

    def __str__(self):
        return f"Membership(g={self.group_id}, u={self.user_id}, admin={self.is_admin})"

class GroupInvite(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        ACCEPTED = "accepted", "Accepted"
        REJECTED = "rejected", "Rejected"

    group = models.ForeignKey(Group, on_delete=models.CASCADE, related_name="invites")
    from_user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="group_invites_sent"
    )
    to_user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="group_invites_received"
    )
    status = models.CharField(
        max_length=16,
        choices=Status.choices,
        default=Status.PENDING
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["group", "to_user"],
                condition=Q(status="pending"),
                name="unique_pending_group_invite",
            )
        ]
        indexes = [
            models.Index(fields=["to_user", "status"]),
            models.Index(fields=["from_user", "status"]),
            models.Index(fields=["group", "status"]),
        ]

    def __str__(self):
        return f"Invite(group={self.group_id}, to={self.to_user_id}, status={self.status})"


class GroupHidden(models.Model):
    group = models.ForeignKey(Group, on_delete=models.CASCADE, related_name="hidden_by")
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="hidden_groups")
    hidden_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["group", "user"], name="unique_group_hidden"),
        ]

    def __str__(self):
        return f"Hidden(g={self.group_id}, u={self.user_id})"


class PasswordResetCode(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="password_reset_codes")
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)

    class Meta:
        indexes = [
            models.Index(fields=["code"]),
            models.Index(fields=["user"]),
        ]

    def is_expired(self):
        return timezone.now() > self.expires_at

    def __str__(self):
        return f"PasswordResetCode(user={self.user_id}, code={self.code}, used={self.is_used})"

class DailySteps(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="daily_steps")
    date = models.DateField()
    steps = models.PositiveIntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["user", "date"], name="unique_daily_steps_per_user_date"),
        ]
        indexes = [
            models.Index(fields=["user", "date"]),
            models.Index(fields=["date"]),
        ]
        ordering = ["-date", "-steps"]

    def __str__(self):
        return f"DailySteps(user={self.user_id}, date={self.date}, steps={self.steps})"

class EmailVerificationCode(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="email_verification_codes")
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_used = models.BooleanField(default=False)

    def is_expired(self):
        return timezone.now() > self.expires_at

    @staticmethod
    def default_expiry():
        return timezone.now() + timedelta(minutes=10)

    def __str__(self):
        return f"{self.user_id} {self.code}"

def user_avatar_upload_to(instance, filename):
    ext = os.path.splitext(filename or "")[1].lower() or ".jpg"
    return f"avatars/user_{instance.user_id}/{uuid.uuid4().hex}{ext}"


class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="profile")
    avatar = models.ImageField(upload_to=user_avatar_upload_to, null=True, blank=True)
    avatar_updated_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=["user"]),
        ]

    def save(self, *args, **kwargs):
        old_avatar_name = None
        if self.pk:
            old = UserProfile.objects.filter(pk=self.pk).only("avatar").first()
            if old and old.avatar and old.avatar.name != getattr(self.avatar, "name", None):
                old_avatar_name = old.avatar.name

        if self.avatar:
            self.avatar_updated_at = timezone.now()
        elif self.avatar is None:
            self.avatar_updated_at = None

        super().save(*args, **kwargs)

        if old_avatar_name:
            storage = self.avatar.storage
            if storage.exists(old_avatar_name):
                storage.delete(old_avatar_name)

    def delete(self, *args, **kwargs):
        avatar_name = self.avatar.name if self.avatar else None
        storage = self.avatar.storage if self.avatar else None
        super().delete(*args, **kwargs)
        if avatar_name and storage and storage.exists(avatar_name):
            storage.delete(avatar_name)

    def __str__(self):
        return f"UserProfile(user={self.user_id})"


class UserLiveLocation(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="live_location",
    )
    latitude = models.FloatField()
    longitude = models.FloatField()
    horizontal_accuracy = models.FloatField(default=0)
    speed = models.FloatField(null=True, blank=True)
    course = models.FloatField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_sharing = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.user_id}: {self.latitude}, {self.longitude}"



class UserTrackPoint(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="track_points",
    )
    latitude = models.FloatField()
    longitude = models.FloatField()

    horizontal_accuracy = models.FloatField(null=True, blank=True)
    speed = models.FloatField(null=True, blank=True)
    course = models.FloatField(null=True, blank=True)
    movement_state = models.CharField(max_length=32, null=True, blank=True)
    steps_delta = models.IntegerField(null=True, blank=True)

    recorded_at = models.DateTimeField()
    day = models.DateField(db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["recorded_at"]

    def __str__(self):
        return f"{self.user_id} {self.recorded_at} ({self.latitude}, {self.longitude})"



class MatchedTrackSegment(models.Model):
    STATUS_PENDING = "pending"
    STATUS_MATCHED = "matched"
    STATUS_FALLBACK = "fallback"
    STATUS_REJECTED = "rejected"

    STATUS_CHOICES = [
        (STATUS_PENDING, "Pending"),
        (STATUS_MATCHED, "Matched"),
        (STATUS_FALLBACK, "Fallback"),
        (STATUS_REJECTED, "Rejected"),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="matched_track_segments",
    )
    day = models.DateField(db_index=True)
    started_at = models.DateTimeField(db_index=True)
    ended_at = models.DateTimeField(db_index=True)

    raw_points = models.JSONField(default=list)
    display_points = models.JSONField(default=list)

    movement_state = models.CharField(max_length=32, null=True, blank=True)
    signal_quality = models.CharField(max_length=16, null=True, blank=True)
    matching_confidence = models.CharField(max_length=16, null=True, blank=True)

    status = models.CharField(
        max_length=16,
        choices=STATUS_CHOICES,
        default=STATUS_PENDING,
        db_index=True,
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["started_at"]

    def __str__(self):
        return f"{self.user_id} {self.day} {self.status} {self.started_at} - {self.ended_at}"