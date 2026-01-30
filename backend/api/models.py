from django.conf import settings
from django.db import models
from django.db.models import Q, F

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