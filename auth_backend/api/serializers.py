from django.contrib.auth import get_user_model, authenticate
from rest_framework import serializers
from django.utils import timezone
import re

from .models import (
    FriendRequest,
    Friendship,
    Group,
    GroupMembership,
    DailySteps,
    UserProfile,
    MatchedTrackSegment,
)
from .models import GroupInvite
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

User = get_user_model()


class UserShortSerializer(serializers.ModelSerializer):
    is_friend = serializers.SerializerMethodField()
    request_sent = serializers.SerializerMethodField()
    request_received = serializers.SerializerMethodField()
    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = (
            "id",
            "username",
            "email",
            "first_name",
            "last_name",
            "avatar_url",
            "is_friend",
            "request_sent",
            "request_received",
        )

    def _ctx_set(self, key: str):
        s = self.context.get(key)
        return s if isinstance(s, set) else set()


    def get_avatar_url(self, obj):
        request = self.context.get("request")
        profile = getattr(obj, "profile", None)
        if not profile or not profile.avatar:
            return None

        url = profile.avatar.url
        return request.build_absolute_uri(url) if request else url

    def get_is_friend(self, obj):
        return obj.id in self._ctx_set("friends_ids")

    def get_request_sent(self, obj):
        return obj.id in self._ctx_set("sent_pending_ids")

    def get_request_received(self, obj):
        return obj.id in self._ctx_set("received_pending_ids")


class FriendRequestSerializer(serializers.ModelSerializer):
    from_user = UserShortSerializer(read_only=True)
    to_user = UserShortSerializer(read_only=True)

    class Meta:
        model = FriendRequest
        fields = ("id", "from_user", "to_user", "status", "created_at")


class CreateFriendRequestSerializer(serializers.Serializer):
    to_user_id = serializers.IntegerField()

    def validate_to_user_id(self, value):
        request = self.context["request"]
        if value == request.user.id:
            raise serializers.ValidationError("Нельзя отправить заявку самому себе.")
        if not User.objects.filter(id=value).exists():
            raise serializers.ValidationError("Пользователь не найден.")
        return value

    def validate(self, attrs):
        request = self.context["request"]
        me = request.user
        to_user_id = attrs["to_user_id"]

        a, b = Friendship.make_pair(me.id, to_user_id)
        if Friendship.objects.filter(user1_id=a, user2_id=b).exists():
            raise serializers.ValidationError("Вы уже друзья.")

        if FriendRequest.objects.filter(from_user=me, to_user_id=to_user_id, status="pending").exists():
            raise serializers.ValidationError("Заявка уже отправлена и ожидает ответа.")

        if FriendRequest.objects.filter(from_user_id=to_user_id, to_user=me, status="pending").exists():
            raise serializers.ValidationError("У вас уже есть входящая заявка от этого пользователя.")

        return attrs


class GroupCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Group
        fields = ["id", "name", "description", "status", "goal_steps", "created_at"]

class GroupListSerializer(serializers.ModelSerializer):
    is_admin = serializers.SerializerMethodField()
    avatar_url = serializers.SerializerMethodField()
    members_count = serializers.SerializerMethodField()
    my_place = serializers.SerializerMethodField()

    class Meta:
        model = Group
        fields = [
            "id",
            "name",
            "description",
            "created_at",
            "is_admin",
            "avatar_url",
            "members_count",
            "my_place",
            "status",
            "goal_steps"
        ]

    def get_is_admin(self, obj):
        user = self.context["request"].user
        m = obj.memberships.filter(user=user).only("is_admin").first()
        return bool(m and m.is_admin)

    def get_avatar_url(self, obj):
        request = self.context.get("request")
        if not obj.avatar:
            return None

        url = obj.avatar.url
        return request.build_absolute_uri(url) if request else url

    def get_members_count(self, obj):
        return obj.memberships.count()

    def get_my_place(self, obj):
        from django.db.models import Sum

        request = self.context["request"]
        today = timezone.localdate()

        member_ids = list(
            obj.memberships.values_list("user_id", flat=True)
        )

        steps_rows = (
            DailySteps.objects
            .filter(user_id__in=member_ids, date=today)
            .values("user_id")
            .annotate(total_steps=Sum("steps"))
        )

        steps_map = {
            row["user_id"]: row["total_steps"] or 0
            for row in steps_rows
        }

        sorted_ids = sorted(
            member_ids,
            key=lambda user_id: (-steps_map.get(user_id, 0), user_id)
        )

        try:
            return sorted_ids.index(request.user.id) + 1
        except ValueError:
            return None


class GroupMemberSerializer(serializers.ModelSerializer):
    id = serializers.IntegerField(source="user.id")
    username = serializers.CharField(source="user.username")
    email = serializers.CharField(source="user.email")
    first_name = serializers.CharField(source="user.first_name", allow_blank=True)
    last_name = serializers.CharField(source="user.last_name", allow_blank=True)
    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = GroupMembership
        fields = [
            "id",
            "username",
            "email",
            "first_name",
            "last_name",
            "avatar_url",
            "is_admin",
            "created_at"
        ]

    def get_avatar_url(self, obj):
        request = self.context.get("request")
        profile = getattr(obj.user, "profile", None)

        if not profile or not profile.avatar:
            return None

        url = profile.avatar.url
        return request.build_absolute_uri(url) if request else url


class GroupLeaderboardSerializer(serializers.Serializer):
    place = serializers.IntegerField()
    user_id = serializers.IntegerField()
    username = serializers.CharField()
    steps = serializers.IntegerField()
    is_me = serializers.BooleanField()
    is_admin = serializers.BooleanField()
    avatar_url = serializers.CharField(required=False, allow_null=True)


class GroupDetailSerializer(serializers.ModelSerializer):
    members = serializers.SerializerMethodField()
    my_is_admin = serializers.SerializerMethodField()
    avatar_url = serializers.SerializerMethodField()
    members_count = serializers.SerializerMethodField()
    my_place = serializers.SerializerMethodField()

    class Meta:
        model = Group
        fields = [
            "id",
            "name",
            "description",
            "status",
            "goal_steps",
            "created_at",
            "members",
            "my_is_admin",
            "avatar_url",
            "members_count",
            "my_place",
        ]
    def get_members(self, obj):
        qs = obj.memberships.select_related("user", "user__profile").order_by("-is_admin", "user__username")
        return GroupMemberSerializer(qs, many=True, context=self.context).data

    def get_my_is_admin(self, obj):
        user = self.context["request"].user
        m = obj.memberships.filter(user=user).only("is_admin").first()
        return bool(m and m.is_admin)

    def get_avatar_url(self, obj):
        request = self.context.get("request")
        if not obj.avatar:
            return None

        url = obj.avatar.url
        return request.build_absolute_uri(url) if request else url

    def get_members_count(self, obj):
        return obj.memberships.count()

    def get_my_place(self, obj):
        from django.db.models import Sum

        request = self.context["request"]
        today = timezone.localdate()

        member_ids = list(obj.memberships.values_list("user_id", flat=True))

        steps_rows = (
            DailySteps.objects
            .filter(user_id__in=member_ids, date=today)
            .values("user_id")
            .annotate(total_steps=Sum("steps"))
        )

        steps_map = {
            row["user_id"]: row["total_steps"] or 0
            for row in steps_rows
        }

        sorted_ids = sorted(
            member_ids,
            key=lambda user_id: (-steps_map.get(user_id, 0), user_id)
        )

        try:
            return sorted_ids.index(request.user.id) + 1
        except ValueError:
            return None


class AddMemberSerializer(serializers.Serializer):
    user_id = serializers.IntegerField()


class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()

    def validate_email(self, value):
        if not User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("Пользователь с таким email не найден.")
        return value


class PasswordResetConfirmSerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(min_length=6, max_length=6)
    password = serializers.CharField(write_only=True, min_length=8)
    password2 = serializers.CharField(write_only=True, min_length=8)

    def validate(self, attrs):
        if attrs["password"] != attrs["password2"]:
            raise serializers.ValidationError({"password2": "Пароли не совпадают."})
        return attrs

class PasswordResetVerifySerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(min_length=6, max_length=6)

    def validate_email(self, value):
        if not User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("Пользователь с таким email не найден.")
        return value

class DailyStepsSyncSerializer(serializers.Serializer):
    steps = serializers.IntegerField(min_value=0)
    date = serializers.DateField(required=False)

    def validate_date(self, value):
        if value > timezone.localdate():
            raise serializers.ValidationError("Нельзя отправить шаги из будущего.")
        return value


class DailyStepsSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source="user.username", read_only=True)

    class Meta:
        model = DailySteps
        fields = ["id", "username", "date", "steps", "updated_at"]


class FriendLeaderboardSerializer(serializers.Serializer):
    place = serializers.IntegerField()
    user_id = serializers.IntegerField()
    username = serializers.CharField()
    steps = serializers.IntegerField()
    is_me = serializers.BooleanField()
    avatar_url = serializers.CharField(required=False, allow_null=True)

class RegisterVerifySerializer(serializers.Serializer):
    email = serializers.EmailField()
    code = serializers.CharField(min_length=6, max_length=6)

    def validate_email(self, value):
        if not User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("Пользователь с таким email не найден.")
        return value


class RegisterResendSerializer(serializers.Serializer):
    email = serializers.EmailField()

    def validate_email(self, value):
        if not User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("Пользователь с таким email не найден.")
        return value


class SetUsernameSerializer(serializers.Serializer):
    username = serializers.CharField(min_length=3, max_length=30)

    def validate_username(self, value):
        value = value.strip()

        if not re.fullmatch(r"[A-Za-z0-9_]+", value):
            raise serializers.ValidationError(
                "Никнейм может содержать только латинские буквы, цифры и _"
            )

        request = self.context["request"]

        if User.objects.filter(username__iexact=value).exclude(id=request.user.id).exists():
            raise serializers.ValidationError("Этот никнейм уже занят.")

        return value

class EmailTokenObtainPairSerializer(TokenObtainPairSerializer):
    username_field = "email"

    email = serializers.EmailField(write_only=True)
    password = serializers.CharField(write_only=True)

    def _get_avatar_url(self, user):
        request = self.context.get("request")
        profile = getattr(user, "profile", None)
        if not profile or not profile.avatar:
            return None

        url = profile.avatar.url
        return request.build_absolute_uri(url) if request else url

    def validate(self, attrs):
        email = attrs.get("email")
        password = attrs.get("password")

        if not email or not password:
            raise serializers.ValidationError("Введите email и пароль.")

        user = User.objects.filter(email__iexact=email).first()
        if user is None:
            raise serializers.ValidationError("Пользователь не найден.")

        auth_user = authenticate(username=user.username, password=password)
        if auth_user is None:
            if not user.is_active:
                raise serializers.ValidationError("Аккаунт не активирован.")
            raise serializers.ValidationError("Неверный пароль.")

        refresh = self.get_token(auth_user)

        return {
            "refresh": str(refresh),
            "access": str(refresh.access_token),
            "user": {
                "id": auth_user.id,
                "email": auth_user.email,
                "username": auth_user.username,
                "avatar_url": self._get_avatar_url(auth_user),
            }
        }

class FriendPreviewSerializer(serializers.ModelSerializer):
    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ("id", "username", "avatar_url")

    def get_avatar_url(self, obj):
        request = self.context.get("request")
        profile = getattr(obj, "profile", None)

        if not profile or not profile.avatar:
            return None

        url = profile.avatar.url
        return request.build_absolute_uri(url) if request else url


class AchievementSerializer(serializers.Serializer):
    code = serializers.CharField()
    title = serializers.CharField()
    current = serializers.IntegerField()
    target = serializers.IntegerField()
    progress = serializers.FloatField()
    is_finished = serializers.BooleanField()


class MyProfileSerializer(serializers.ModelSerializer):
    avatar_url = serializers.SerializerMethodField()
    current_streak_days = serializers.IntegerField(read_only=True)
    total_steps = serializers.IntegerField(read_only=True)
    friends_count = serializers.IntegerField(read_only=True)
    friends_preview = FriendPreviewSerializer(many=True, read_only=True)
    achievements = AchievementSerializer(many=True, read_only=True)

    class Meta:
        model = User
        fields = (
            "id",
            "username",
            "email",
            "first_name",
            "last_name",
            "avatar_url",
            "current_streak_days",
            "total_steps",
            "friends_count",
            "friends_preview",
            "achievements",
        )

    def get_avatar_url(self, obj):
        request = self.context.get("request")
        profile = getattr(obj, "profile", None)

        if not profile or not profile.avatar:
            return None

        url = profile.avatar.url
        return request.build_absolute_uri(url) if request else url

class AvatarUploadSerializer(serializers.Serializer):
    avatar = serializers.ImageField(required=True)

    MAX_FILE_SIZE = 5 * 1024 * 1024
    ALLOWED_CONTENT_TYPES = {
        "image/jpeg",
        "image/png",
        "image/webp",
    }

    def validate_avatar(self, value):
        content_type = getattr(value, "content_type", None)
        if content_type not in self.ALLOWED_CONTENT_TYPES:
            raise serializers.ValidationError("Поддерживаются только JPG, PNG и WEBP.")

        if value.size > self.MAX_FILE_SIZE:
            raise serializers.ValidationError("Размер файла не должен превышать 5 МБ.")

        return value


class AvatarResponseSerializer(serializers.ModelSerializer):
    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = UserProfile
        fields = ("avatar_url", "avatar_updated_at")

    def get_avatar_url(self, obj):
        request = self.context.get("request")
        if not obj.avatar:
            return None

        url = obj.avatar.url
        return request.build_absolute_uri(url) if request else url


class LiveLocationUpdateSerializer(serializers.Serializer):
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    horizontal_accuracy = serializers.FloatField(required=False, default=0)
    speed = serializers.FloatField(required=False, allow_null=True)
    course = serializers.FloatField(required=False, allow_null=True)
    is_sharing = serializers.BooleanField(required=False, default=True)

    def validate_latitude(self, value):
        if not (-90 <= value <= 90):
            raise serializers.ValidationError("Некорректная широта.")
        return value

    def validate_longitude(self, value):
        if not (-180 <= value <= 180):
            raise serializers.ValidationError("Некорректная долгота.")
        return value


class FriendLiveLocationSerializer(serializers.Serializer):
    user_id = serializers.IntegerField()
    username = serializers.CharField()
    avatar_url = serializers.CharField(required=False, allow_null=True)
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    updated_at = serializers.DateTimeField()
    is_me = serializers.BooleanField()


class TrackPointWriteSerializer(serializers.Serializer):
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    horizontal_accuracy = serializers.FloatField(required=False, allow_null=True)
    speed = serializers.FloatField(required=False, allow_null=True)
    course = serializers.FloatField(required=False, allow_null=True)
    movement_state = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    steps_delta = serializers.IntegerField(required=False, allow_null=True)
    recorded_at = serializers.DateTimeField()

    def validate_latitude(self, value):
        if not (-90 <= value <= 90):
            raise serializers.ValidationError("Некорректная широта.")
        return value

    def validate_longitude(self, value):
        if not (-180 <= value <= 180):
            raise serializers.ValidationError("Некорректная долгота.")
        return value


class TrackPointsBatchSerializer(serializers.Serializer):
    points = TrackPointWriteSerializer(many=True)


class TrackPointReadSerializer(serializers.Serializer):
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    horizontal_accuracy = serializers.FloatField(required=False, allow_null=True)
    speed = serializers.FloatField(required=False, allow_null=True)
    course = serializers.FloatField(required=False, allow_null=True)
    movement_state = serializers.CharField(required=False, allow_null=True)
    steps_delta = serializers.IntegerField(required=False, allow_null=True)
    recorded_at = serializers.DateTimeField()

class FriendTrackPointSerializer(serializers.Serializer):
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    horizontal_accuracy = serializers.FloatField(required=False, allow_null=True)
    speed = serializers.FloatField(required=False, allow_null=True)
    course = serializers.FloatField(required=False, allow_null=True)
    movement_state = serializers.CharField(required=False, allow_null=True)
    steps_delta = serializers.IntegerField(required=False, allow_null=True)
    recorded_at = serializers.DateTimeField()


class FriendTrackSerializer(serializers.Serializer):
    user_id = serializers.IntegerField()
    username = serializers.CharField()
    avatar_url = serializers.CharField(required=False, allow_null=True)
    points = FriendTrackPointSerializer(many=True)

class DisplayPointSerializer(serializers.Serializer):
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()


class MatchedTrackSegmentSerializer(serializers.Serializer):
    started_at = serializers.DateTimeField()
    ended_at = serializers.DateTimeField()
    status = serializers.CharField()
    signal_quality = serializers.CharField(required=False, allow_null=True)
    matching_confidence = serializers.CharField(required=False, allow_null=True)
    display_points = DisplayPointSerializer(many=True)


class FriendMatchedTrackSerializer(serializers.Serializer):
    user_id = serializers.IntegerField()
    username = serializers.CharField()
    avatar_url = serializers.CharField(required=False, allow_null=True)
    segments = MatchedTrackSegmentSerializer(many=True)

class NotificationUserSerializer(serializers.ModelSerializer):
    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ["id", "username", "email", "first_name", "last_name", "avatar_url"]

    def get_avatar_url(self, obj):
        request = self.context.get("request")
        profile = getattr(obj, "profile", None)

        if not profile or not profile.avatar:
            return None

        url = profile.avatar.url
        return request.build_absolute_uri(url) if request else url

class NotificationGroupSerializer(serializers.ModelSerializer):
    avatar_url = serializers.SerializerMethodField()

    class Meta:
        model = Group
        fields = ["id", "name", "avatar_url"]

    def get_avatar_url(self, obj):
        request = self.context.get("request")

        if not getattr(obj, "avatar", None):
            return None

        url = obj.avatar.url
        return request.build_absolute_uri(url) if request else url